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
# install into a prefix
KIWI_PREFIX=$tmp/p bash install.sh install >/dev/null
test -x "$tmp/p/bin/kiwi-stack" && test -f "$tmp/p/lib/kiwi-stack/lib.sh"
KIWI_PREFIX=$tmp/p bash install.sh uninstall >/dev/null
test ! -e "$tmp/p/bin/kiwi-stack"
echo "kiwi-stack checks: ok"
