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
        *" --list-ports "*) echo "443/tcp 80/tcp"; return 0 ;;       # 443 is there already, in both
        *" --query-source="*) return 1 ;;
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
# A new site gives every container of the machine another name (an AddHost line in its quadlet).
# That alone restarts nothing: the names are written into the running container's hosts file, in
# place. A quadlet that changed in anything else restarts as before; names an apply could not hand
# over (it ended before) become a restart at the next one.
mkdir -p "$tmp/nm/q" "$tmp/nm/etc"
printf '[Container]\nImage=a\nAddHost=cloud.m.home:172.128.0.5\nAddHost=gone.m.home:172.128.0.5\nIP=172.128.0.9\n' > "$tmp/nm/q/kn-app.container"
printf '[Container]\nImage=b\nAddHost=cloud.m.home:172.128.0.5\n' > "$tmp/nm/q/kn-other.container"
printf '127.0.0.1\tlocalhost\n172.128.0.5\tcloud.m.home\n172.128.0.5\tgone.m.home\n172.128.0.9\tkn-app\n' > "$tmp/nm/hosts"
inode=$(stat -c %i "$tmp/nm/hosts")
out=$(KS_QUADLET_DIR=$tmp/nm/q KS_PENDING=$tmp/nm/etc/restart-pending KS_PENDING_NAMES=$tmp/nm/etc/names-pending KS_PENDING_UNITS=$tmp/nm/etc/units-pending KS_SYSTEMD_DIR=$tmp/nm/units HOSTS=$tmp/nm/hosts bash -c '
set -euo pipefail
. ./lib.sh
ks_say() { echo "say: $*"; }
ks_replace() { mv "$1" "$2"; }
systemctl() { [[ $1 == is-active ]]; }
podman() { [[ $4 == kn-app ]] && echo "$HOSTS"; }
KS_STACK_DIR=/nonexistent; KS_STACK_FILES=(); KS_STACK_UNITS=(); KS_STACK_QUADLETS=(kn-app.container kn-other.container); KS_STACK_SERVICES=(kn-app kn-other)
ks_stack_remember
sed -i "s/^AddHost=gone.m.home.*/AddHost=vault.m.home:172.128.0.5/" "$KS_QUADLET_DIR/kn-app.container"
sed -i "s/^Image=b/Image=c/" "$KS_QUADLET_DIR/kn-other.container"; echo "AddHost=vault.m.home:172.128.0.5" >> "$KS_QUADLET_DIR/kn-other.container"
ks_stack_compare
ks_stack_note_pending
echo "changed: ${KS_CHANGED[*]##*/}; names only: ${KS_NAMES_ONLY[*]##*/}; noted: $(cat "$KS_PENDING_NAMES")"
echo "due: $(ks_stack_restart_due | tr "\n" " ")"
ks_stack_names_now
echo "failed: ${KS_NAMES_FAILED[*]:-none}; noted still: $([[ -e $KS_PENDING_NAMES ]] && echo yes || echo no)"
# an apply that ended before it handed the names over: the next one restarts that container
echo kn-app > "$KS_PENDING_NAMES"; rm -f "$KS_PENDING"; KS_NAMES_ONLY=(); KS_CHANGED=()
ks_stack_note_pending
echo "after a cut-off run, due: $(ks_stack_restart_due | tr "\n" " ")"')
[[ $out == "changed: kn-other.container; names only: kn-app.container; noted: kn-app
due: kn-other 
say: 1 container(s) took the machine's new names without a restart
failed: none; noted still: no
after a cut-off run, due: kn-app " ]]
[[ $(cat "$tmp/nm/hosts") == $'127.0.0.1\tlocalhost\n172.128.0.9\tkn-app\n172.128.0.5\tcloud.m.home\n172.128.0.5\tvault.m.home' ]]
[[ $(stat -c %i "$tmp/nm/hosts") == "$inode" ]]                   # written in place: the container sees it
# A file that is there already as it should be is left alone (the same inode: a container has it
# mounted), one whose content or mode differs is replaced; a unit that did not change costs no
# reload of systemd
out=$(bash -c '
set -euo pipefail
. ./lib.sh
d=$1; reloads=0
systemctl() { [[ $1 == daemon-reload ]] && reloads=$((reloads + 1)); return 0; }
ks_parent_dir() { mkdir -p "$(dirname "$1")"; }
me=$(id -un):$(id -gn)
ks_write "$d/f" 0644 "$me" <<<one; a=$(stat -c %i "$d/f"); echo "wrote $KS_WROTE"
ks_write "$d/f" 0644 "$me" <<<one; echo "wrote $KS_WROTE same inode $([[ $(stat -c %i "$d/f") == "$a" ]] && echo yes || echo no)"
ks_write "$d/f" 0644 "$me" <<<two; echo "wrote $KS_WROTE"
ks_write "$d/f" 0600 "$me" <<<two; echo "wrote $KS_WROTE mode $(stat -c %a "$d/f")"
KS_SYSTEMD_DIR=$d/units
# units are root'"'"'s; here they are written as this user, the rest of ks_unit is the real one
ks_write() { mkdir -p "$(dirname "$1")"; cat > "$1.tmp"; ks_put "$1.tmp" "$1" "${2:-0644}" "$me"; }
ks_unit a.service <<<"[Unit]"; ks_unit a.service <<<"[Unit]"; ks_unit a.service <<<"[Unit] "
echo "reloads $reloads"' _ "$tmp/put")
[[ $out == $'wrote 1\nwrote 0 same inode yes\nwrote 1\nwrote 1 mode 600\nreloads 2' ]]
# The stack's units start again when a file of theirs changed (the unit, a script it runs, a file
# beside it of the same name), when the stack started from nothing, when an earlier apply ended
# before they ran, and one by one when a unit is not fine. A change elsewhere in the stack, a
# restarted container, leaves them as they run. A changed host-side file no unit claims starts all.
mkdir -p "$tmp/un/units" "$tmp/un/stack/kiwi/env" "$tmp/un/stack/kiwi/backup"
printf '[Service]\nExecStart=/bin/sh %s/un/stack/kiwi/gw.sh start\n' "$tmp" > "$tmp/un/units/kn-gateway.service"
printf '[Service]\nExecStart=/usr/bin/bash %s/un/stack/kiwi/cloud-accounts.sh\n' "$tmp" > "$tmp/un/units/kn-cloud-accounts.service"
printf '[Service]\nExecStart=%s/un/stack/kiwi/backup.sh backup\n' "$tmp" > "$tmp/un/units/kn-backup.service"
printf '[Timer]\nOnCalendar=daily\n' > "$tmp/un/units/kn-backup.timer"
printf '[Service]\nExecStart=/bin/true\n' > "$tmp/un/units/kn-broken.service"
out=$(KS_PENDING=$tmp/un/restart-pending bash -c '
set -euo pipefail
. ./lib.sh
KS_SYSTEMD_DIR=$1/units; KS_STACK_DIR=$1/stack
ks_say() { echo "say: $*"; }
ks_warn() { echo "warn: $*"; }
systemctl() {
    case $1 in
        enable) return 0 ;;
        is-active) [[ $3 != kn-broken.service && $3 != kn-backup.service ]] ;;
        show) echo "Result=exit-code"; echo "ExecMainStatus=1"; echo "ExecMainExitTimestampMonotonic=5" ;;
        restart) echo "restart ${*: -1}" ;;
    esac
}
KS_STACK_UNITS=(kn-gateway.service kn-cloud-accounts.service kn-backup.service kn-backup.timer kn-broken.service)
run() { echo "-- $1"; shift; KS_CHANGED=("$@"); ks_stack_units_start 0 | grep -v "^say:" || true; }
run "nothing changed"
run "a container'"'"'s files changed" "$KS_STACK_DIR/kiwi/env/kn-vault.env" /etc/containers/systemd/kn-vault.container
run "the sign-in set-up'"'"'s settings changed" "$KS_STACK_DIR/kiwi/cloud-accounts.env"
run "the gateway'"'"'s unit changed" "$KS_SYSTEMD_DIR/kn-gateway.service"
echo "-- and the same through the apply'"'"'s own note of it"; KS_STACK_FILES=(); KS_STACK_QUADLETS=(); KS_STACK_SERVICES=()
KS_CHANGED=("$KS_STACK_DIR/kiwi/gw.sh"); ks_stack_note_pending; ks_stack_units_start 0 | grep -v "^say:" || true
run "the backup'"'"'s settings changed" "$KS_STACK_DIR/kiwi/backup/restic.env"
run "a host-side file no unit names" "$KS_STACK_DIR/kiwi/something-new.conf"
echo "-- from nothing"; KS_CHANGED=(); ks_stack_units_start 1 | grep -c "^restart"
echo "-- an earlier apply ended before its units ran"; : > "$(ks_pending_units)"; KS_STACK_FILES=(); KS_STACK_QUADLETS=(); KS_STACK_SERVICES=()
ks_stack_note_pending; ks_stack_units_start 0 | grep -c "^restart"
echo "marker left: $([[ -e $(ks_pending_units) ]] && echo yes || echo no)"' _ "$tmp/un")
[[ $out == "-- nothing changed
restart kn-broken.service
-- a container's files changed
restart kn-broken.service
-- the sign-in set-up's settings changed
restart kn-cloud-accounts.service
restart kn-broken.service
-- the gateway's unit changed
restart kn-gateway.service
restart kn-broken.service
-- and the same through the apply's own note of it
restart kn-gateway.service
restart kn-broken.service
-- the backup's settings changed
restart kn-backup.service
restart kn-broken.service
-- a host-side file no unit names
restart kn-gateway.service
restart kn-cloud-accounts.service
restart kn-backup.service
restart kn-backup.timer
restart kn-broken.service
-- from nothing
5
-- an earlier apply ended before its units ran
5
marker left: no" ]]
# The role's log is root's alone, and a trace (bash -x) is switched off before anything goes into
# it: the script carries the stack's files in its variables
touch "$tmp/role.log"; chmod 0644 "$tmp/role.log"
out=$(bash -x -c '
. ./lib.sh
KS_LOG=$1
ks_log_open 2>/dev/null
case $- in *x*) echo traced ;; *) echo quiet ;; esac
stat -c %a "$KS_LOG"' _ "$tmp/role.log" 2>/dev/null)
[[ $out == $'quiet\n600' ]]
echo "kiwi-stack checks: ok"
