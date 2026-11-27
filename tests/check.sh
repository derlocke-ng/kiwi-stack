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
# a replaced file is whole: the new content, its mode, nothing left behind
KS_TMP=$tmp bash -c '
set -euo pipefail
. ./lib.sh
d=$KS_TMP/rep; mkdir -p "$d"; echo old > "$d/f"
echo new | ks_write "$d/f" 0640 "$(id -u):$(id -g)"
[[ $(cat "$d/f") == new && $(stat -c %a "$d/f") == 640 && ! -e $d/f.tmp ]]
printf x > "$d/t"; ks_replace "$d/t" "$d/f"; [[ $(cat "$d/f") == x && ! -e $d/t ]]
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
# a run that ends before its restarts (an image did not pull): the next one still restarts them
KS_PENDING=$d/restart-pending
trap '\''echo "ERR trap: $BASH_COMMAND" >&2; exit 9'\'' ERR; set -E      # as the role script runs it
[[ -z $(ks_stack_restart_due) ]] || true                       # no file, nothing changed: quiet
ks_stack_note_pending
ks_stack_remember; ks_stack_compare                             # the next run: the files are the same now
[[ -z $(ks_stack_changed_services) ]]
[[ $(ks_stack_restart_due | tr "\n" " ") == "kn-pihole kn-portainer kn-vault " ]]
'
# a service asleep (a game server nobody plays on) is not down; a stopped one without the mark is
bash -c '
set -euo pipefail
eval "$(sed -n "/^verify() {/,/^}/p" kiwi-stack)"
eval "$(sed -n "/^misrouted() {/,/^}/p" kiwi-stack)"
podman() { return 125; }            # a container asleep does not exist: inspect fails
ip() { :; }
systemctl() { [[ $2 == kn-up.service ]] && echo active || echo inactive; }
STACK_RUNTIME=podman STACK_SERVICES="kn-up kn-game-a" KS_VERIFY_TRIES=0 KS_SLEEPING='"$tmp"'/sleeping
mkdir -p "$KS_SLEEPING"
if verify 2>/dev/null; then echo "a stopped service without the mark must fail"; exit 1; fi
touch "$KS_SLEEPING/kn-game-a"
[[ $(verify) == "all kn-up, kn-game-a running, asleep until someone comes: kn-game-a" ]]
# as `kiwi-stack verify` runs it: set -e alive (inside `x || y` bash switches it off, and the bug hid)
set +e; (set -e; verify >/dev/null); rc=$?; set -e
(( rc == 0 )) || { echo "verify failed ($rc) with a container asleep (its inspect fails)"; exit 1; }
'
# install into a prefix
KIWI_PREFIX=$tmp/p bash install.sh install >/dev/null
test -x "$tmp/p/bin/kiwi-stack" && test -f "$tmp/p/lib/kiwi-stack/lib.sh"
KIWI_PREFIX=$tmp/p bash install.sh uninstall >/dev/null
test ! -e "$tmp/p/bin/kiwi-stack"
# the groups of the home network: one rule set, only what is for this machine, a bad entry left out
bash -c '
set -euo pipefail
. ./lib.sh
KS_STACK_LAN_RULES=("192.168.20.0/24 tcp:443,tcp:80" "192.168.30.0/24 none" "192.168.40.0/24 all" "bad x")
out=$(ks_lan_nft 2>/dev/null)
grep -q "^delete table inet kiwi_lan$" <<<"$out"
grep -q "fib daddr type != local accept" <<<"$out"
grep -q "ip saddr 192.168.20.0/24 tcp dport 443 accept" <<<"$out"
grep -q "ip saddr 192.168.20.0/24 drop" <<<"$out"
grep -q "ip saddr 192.168.30.0/24 drop" <<<"$out"
grep -q "ip saddr 192.168.40.0/24 accept" <<<"$out"
if grep -q "bad" <<<"$out"; then exit 1; fi
'
# tagged interfaces: names that fit, a bad entry left out, the card of the default route when none is named
bash -c '
set -euo pipefail
. ./lib.sh
[[ $(ks_vlan_name eth0 20) == eth0.20 && $(ks_vlan_name enp0s20f0u1u2 4000) == vlan4000 ]]
ip() { [[ $* == "-o -4 route show default" ]] && echo "default via 192.168.1.1 dev enp1s0 proto static"; }
KS_STACK_VLANS=("20 192.168.20.5/24" "30 192.168.30.5/24 eth1" "5000 10.0.0.1/24" "x y")
out=$(ks_vlan_lines 2>/dev/null)
[[ $out == "enp1s0 20 192.168.20.5/24 enp1s0.20"$'"'"'\n'"'"'"eth1 30 192.168.30.5/24 eth1.30" ]]
unset KS_STACK_VLANS
[[ -z $(ks_vlan_lines) ]]
bash -n <<<"$KS_VLANS_UP"
'
# room for a changed image on a full disk: only a container of the stack whose image it no longer names goes
bash -c '
set -euo pipefail
. ./lib.sh
log=$(mktemp)
podman() {
    case "$1 $2" in
        "info --format") echo /var/lib/containers/storage ;;
        # as podman shows them: inspect all 64 hex digits, ps the first 12
        "image inspect") case $5 in
            *nginx:1-alpine) echo 1111111111111111111111111111111111111111111111111111111111111111 ;;
            *pihole*) echo 2222222222222222222222222222222222222222222222222222222222222222 ;;
            *) return 1 ;; esac ;;
        "ps -a") printf "%s\n" "km-nginx 333333333333" "km-pihole 222222222222" "other 444444444444" ;;
        *) echo "podman $*" >> "$log" ;;
    esac
}
systemctl() { echo "systemctl $*" >> "$log"; }
df() { printf "Use%%\n 94%%\n"; }
KS_STACK_RUNTIME=podman
KS_STACK_IMAGES=(docker.io/library/nginx:1-alpine docker.io/pihole/pihole:latest)
KS_STACK_SERVICES=(km-nginx km-pihole)
ks_stack_make_room docker.io/library/nginx:1-alpine >/dev/null
grep -q "systemctl stop km-nginx.service" "$log"
grep -q "podman rmi 333333333333" "$log"
if grep -q "pihole\|other" "$log"; then exit 1; fi    # on an image the stack names, or not the stack'"'"'s: stays
df() { printf "Use%%\n 50%%\n"; }
: > "$log"
ks_stack_make_room docker.io/library/nginx:1-alpine >/dev/null
[[ ! -s $log ]]                              # room enough: nothing stops
'
# the status leaves out conmon's cgroups notes, nothing else
out=$(printf '%s\n' "Nov 19 04:16:22 papaya.home conmon[2479452]: conmon c8b6188d0921 <nwarn>: Failed to open cgroups file: /sys/fs/cgroup/x/memory.events" \
                     "Nov 19 04:16:23 papaya.home systemd[1]: Started kn-x.service." | bash -c "$(sed -n '/^quiet_conmon()/p' kiwi-stack); quiet_conmon")
[[ $out == "Nov 19 04:16:23 papaya.home systemd[1]: Started kn-x.service." ]]
# a unit's status without its log; a failed one with its last lines
out=$(bash -c "$(sed -n '/^unit_status() {/,/^}/p' kiwi-stack)"'
STACK_UNITS="km-acme.timer km-broken.service"
systemctl() { case $1 in is-failed) [[ ${3:-} == km-broken.service ]] ;; status) echo "status ${*:2}" ;; esac; }
unit_status')
[[ $out == $'status --no-pager -n 0 km-acme.timer\nstatus --no-pager -n 10 km-broken.service' ]]
# the backup before an update asks the backup module for a backup (its script wants the verb:
# without it, it prints its usage and every update stopped, 0.9.31)
backup_first=$(sed -n '/^backup_first() {/,/^}/p' kiwi-stack)
mkdir -p "$tmp/bf/kiwi"
printf '#!/bin/sh\n[ "$1" = backup ] || { echo "usage: ..." >&2; exit 1; }\necho made\n' > "$tmp/bf/kiwi/backup.sh"
chmod +x "$tmp/bf/kiwi/backup.sh"
[[ $(STACK_DIR=$tmp/bf bash -c "$backup_first"$'\nbackup_first') == $'a backup first\nmade' ]]
# firewalld: a port goes into the permanent and the running configuration, one already there is
# left alone, and nothing reloads (a reload dropped the stack network from the trusted sources and
# the containers lost their DNS, 0.9.34); the stack's subnets, read from its quadlets, are kept
# as trusted sources in both
mkdir -p "$tmp/fw/q"
printf '[Network]\nNetworkName=knet-node\nSubnet=172.128.0.0/24\nGateway=172.128.0.1\n' > "$tmp/fw/q/knet-node.network"
out=$(KS_QUADLET_DIR=$tmp/fw/q bash -c '
set -euo pipefail
. ./lib.sh
ks_say() { :; }
systemctl() { [[ $1 == is-active ]]; }
firewall-cmd() {
    local a=" $* "
    case $a in
        *" --query-port=443/tcp "*) return 0 ;;                      # there already, in both
        *" --query-port="*|*" --query-source="*) return 1 ;;
    esac
    echo "$*"
}
KS_STACK_RUNTIME=podman
ks_firewall_open 443/tcp 51820/udp 2456-2458/udp
ks_firewall_trust_stack
KS_STACK_RUNTIME=docker
ks_firewall_trust_stack')
[[ $out == "-q --permanent --add-port=51820/udp
-q --add-port=51820/udp
-q --permanent --add-port=2456-2458/udp
-q --add-port=2456-2458/udp
-q --permanent --zone=trusted --add-source=172.128.0.0/24
-q --zone=trusted --add-source=172.128.0.0/24" ]]
echo "kiwi-stack checks: ok"
