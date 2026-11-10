#!/usr/bin/env bash
# What can be checked without a machine: the scripts parse and shellcheck,
# the CLI's argument handling, the library's pure functions.
set -euo pipefail
cd "$(dirname "$0")/.."
shellcheck -S warning kiwi-stack install.sh tests/check.sh
shellcheck -S warning -s bash lib.sh
bash -n kiwi-stack lib.sh install.sh

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# apply without a directory: usage, exit 1
if KIWI_STACK_LIB=$PWD/lib.sh ./kiwi-stack apply 2>"$tmp/err"; then echo "apply without DIR must fail"; exit 1; fi
grep -q 'usage: kiwi-stack apply DIR' "$tmp/err"
# a directory that is not a bundle: a message naming stack.sh (as root), or the root check first
mkdir -p "$tmp/nobundle"
if KIWI_STACK_LIB=$PWD/lib.sh ./kiwi-stack apply "$tmp/nobundle" 2>"$tmp/err"; then echo "apply on a non-bundle must fail"; exit 1; fi
grep -Eq 'must run as root|not a stack bundle' "$tmp/err"
# any other verb without a stack on this machine: says so, exit 1
if [[ ! -f /etc/kiwi-server/stack.env ]]; then
    if ./kiwi-stack status 2>"$tmp/err"; then echo "status without a stack must fail"; exit 1; fi
    grep -q 'no stack on this machine yet' "$tmp/err"
fi
# the library loads and its pure helpers work
bash -c '
set -euo pipefail
. ./lib.sh
[[ $(ks_detect_os) =~ ^(debian|ostree|other)$ ]]
KS_BUNDLE_DIR=/b
[[ $(ks_bundle_path stack/x/y) == /b/x/y ]]
[[ $(ks_bundle_path unit/a.service) == /b/host-units/a.service ]]
[[ $(ks_bundle_path quadlet/a.container) == /b/quadlets/a.container ]]
[[ $(ks_bundle_path ca_cert) == /b/kiwi/ca/kiwiCA.crt ]]
[[ $(ks_bundle_path kiwi-stack) == /usr/local/bin/kiwi-stack ]]
'
# a rendered file whose module left goes; a kept one, data and a moved stack stay
KS_TMP=$tmp bash -c '
set -euo pipefail
. ./lib.sh
ks_say() { :; }
d=$KS_TMP/stack; mkdir -p "$d/kiwi" "$d/kn-vault"
touch "$d/kiwi/backup.sh" "$d/kiwi/gw.sh" "$d/kn-vault/data.db" "$d/kn-vault/config.hcl"
KS_STACK_ENV=$KS_TMP/stack.env
printf "STACK_DIR=%s\nSTACK_FILES=\"kiwi/backup.sh kiwi/gw.sh kn-vault/config.hcl ../etc/passwd\"\n" "$d" > "$KS_STACK_ENV"
KS_STACK_FILES=("kiwi/gw.sh:0755")
ks_stack_drop_files "$KS_TMP/elsewhere"
[[ -f $d/kiwi/backup.sh ]]
ks_stack_drop_files "$d"
[[ ! -e $d/kiwi/backup.sh && ! -e $d/kn-vault/config.hcl ]]
[[ -f $d/kiwi/gw.sh && -f $d/kn-vault/data.db ]]
'
# a running stack restarts what changed: a quadlet, a mounted file, a file under a mounted dir, an env file
KS_TMP=$tmp bash -c '
set -euo pipefail
. ./lib.sh
d=$KS_TMP/changed; q=$d/quadlets; mkdir -p "$d/stack/kn-nginx" "$d/stack/kn-vault" "$d/stack/kiwi/env" "$q"
KS_STACK_DIR=$d/stack KS_QUADLET_DIR=$q
KS_STACK_SERVICES=(kn-nginx kn-vault kn-pihole kn-portainer)
KS_STACK_FILES=("kn-nginx/nginx.conf:0644" "kn-vault/config.hcl:0644" "kiwi/env/kn-pihole.env:0600")
KS_STACK_QUADLETS=(kn-nginx.container kn-vault.container kn-pihole.container kn-portainer.container)
for f in kn-nginx/nginx.conf kn-vault/config.hcl kiwi/env/kn-pihole.env; do echo old > "$d/stack/$f"; done
printf "Volume=%s:/etc/nginx/nginx.conf:ro,z\n" "$d/stack/kn-nginx/nginx.conf" > "$q/kn-nginx.container"
printf "Volume=%s:/data:z\n" "$d/stack/kn-vault" > "$q/kn-vault.container"
printf "EnvironmentFile=%s\n" "$d/stack/kiwi/env/kn-pihole.env" > "$q/kn-pihole.container"
printf "Image=portainer\n" > "$q/kn-portainer.container"
ks_stack_remember
ks_stack_compare
[[ -z $(ks_stack_changed_services) ]]                         # nothing written: nothing restarts
echo new > "$d/stack/kn-vault/config.hcl"                      # under a mounted directory
echo new > "$d/stack/kiwi/env/kn-pihole.env"                   # an env file
printf "Image=portainer:2\n" > "$q/kn-portainer.container"     # a quadlet
ks_stack_compare
[[ $(ks_stack_changed_services | tr "\n" " ") == "kn-vault kn-pihole kn-portainer " ]]
'
# install into a prefix
KIWI_PREFIX=$tmp/p bash install.sh install >/dev/null
test -x "$tmp/p/bin/kiwi-stack" && test -f "$tmp/p/lib/kiwi-stack/lib.sh"
KIWI_PREFIX=$tmp/p bash install.sh uninstall >/dev/null
test ! -e "$tmp/p/bin/kiwi-stack"
echo "kiwi-stack checks: ok"
