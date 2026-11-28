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
# a file its part reads again by itself (a module's live output: the DNS names in dnsmasq's
# hostsdir) restarts nothing when it changes; another file in the same mounted folder still does
KS_TMP=$tmp bash -c '
set -euo pipefail
. ./lib.sh
d=$KS_TMP/live; q=$d/quadlets; mkdir -p "$d/stack/kn-pihole/names" "$q"
KS_STACK_DIR=$d/stack KS_QUADLET_DIR=$q
KS_STACK_SERVICES=(kn-pihole)
KS_STACK_FILES=("kn-pihole/names/kiwi.hosts:0644" "kn-pihole/names/other:0644")
KS_STACK_LIVE=("kn-pihole/names/kiwi.hosts")
KS_STACK_QUADLETS=(kn-pihole.container)
for f in kn-pihole/names/kiwi.hosts kn-pihole/names/other; do echo old > "$d/stack/$f"; done
printf "Volume=%s:/etc/kiwi-names:ro,z\n" "$d/stack/kn-pihole/names" > "$q/kn-pihole.container"
trap '\''echo "ERR trap: $BASH_COMMAND" >&2; exit 9'\'' ERR; set -E      # as the role script runs it
ks_stack_remember
echo "10.9.0.7 new.home" > "$d/stack/kn-pihole/names/kiwi.hosts"
ks_stack_compare
[[ -z $(ks_stack_changed_services) ]]                         # a new name: Pi-hole goes on running
[[ ${KS_LIVE_CHANGED[*]##*/} == kiwi.hosts && -z ${KS_CHANGED[*]:-} ]]
echo new > "$d/stack/kn-pihole/names/other"
ks_stack_compare
[[ $(ks_stack_changed_services) == kn-pihole ]]
unset KS_STACK_LIVE                                           # the manifest of an older kiwi-server
ks_stack_remember; echo "10.9.0.8 new.home" > "$d/stack/kn-pihole/names/kiwi.hosts"; ks_stack_compare
[[ $(ks_stack_changed_services) == kn-pihole ]]
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
# one that runs but fails its own health check is named, and verify still passes; another stack'"'"'s is not
podman() { [[ $1 == ps ]] && printf "kn-up\nsomeone-elses\n"; return 0; }
said=$(verify 2>&1 >/dev/null)
[[ $said == "unhealthy (it runs, and its own check fails): kn-up — kiwi-stack logs <name>" ]] || { echo "verify on an unhealthy one said: $said"; exit 1; }
podman() { return 0; }
[[ -z $(verify 2>&1 >/dev/null) ]]
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
busctl() { return 1; }          # (never the firewalld of this computer) not on D-Bus: firewall-cmd is asked
firewall-cmd() {
    local a=" $* "
    case $a in
        *" --list-ports "*) echo "443/tcp 80/tcp"; return 0 ;;       # 443 is there already, in both
        *" --list-sources "*) return 0 ;;                            # nothing trusted yet
        *" --get-default-zone "*) echo public; return 0 ;;
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
# as in the role: its error trap, inherited by subshells. A unit that names no script must not trip it
# (it fires in the subshell that feeds a loop, so its word goes to a file, not to the loop)
trap '"'"'echo "$BASH_COMMAND" >> "$KS_SYSTEMD_DIR/../trapped"; exit 1'"'"' ERR
set -E
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
if [[ -s $tmp/un/trapped ]]; then echo "the role's error trap fired while the units were judged: $(sort -u "$tmp/un/trapped" | tr '\n' ' ')"; exit 1; fi
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
# A part's word on its new settings (KS_STACK_CHECKS) before the stack is written: asked in a
# throwaway container with the new files from a copy; not asked without its image, or when nothing
# of it changes; its no stops the apply while every file on the machine is still the old one
mkdir -p "$tmp/pf/b/quadlets" "$tmp/pf/b/kn-nginx" "$tmp/pf/stack/kn-nginx/acme" "$tmp/pf/q" "$tmp/pf/run"
printf 'Image=nginx:1\nVolume=%s/kn-nginx/nginx.conf:/etc/nginx/nginx.conf:ro,z\nVolume=%s/kn-nginx/privkey.pem:/etc/nginx/privkey.pem:ro,z\nVolume=%s/kn-nginx/acme:/etc/nginx/acme:z\nVolume=%s/kn-nginx/log:/var/log/nginx:z\nVolume=kn-data:/data\nAddHost=cloud.home:10.1.0.5\n' \
    "$tmp/pf/stack" "$tmp/pf/stack" "$tmp/pf/stack" "$tmp/pf/stack" > "$tmp/pf/b/quadlets/kn-nginx.container"
echo "new config" > "$tmp/pf/b/kn-nginx/nginx.conf"; echo key > "$tmp/pf/b/kn-nginx/privkey.pem"
echo "old config" > "$tmp/pf/stack/kn-nginx/nginx.conf"; echo key > "$tmp/pf/stack/kn-nginx/privkey.pem"
cp "$tmp/pf/b/quadlets/kn-nginx.container" "$tmp/pf/q/kn-nginx.container"
out=$(bash -c '
set -euo pipefail
. ./lib.sh
t=$1; KS_BUNDLE_DIR=$t/b; KS_STACK_DIR=$t/stack; KS_QUADLET_DIR=$t/q; KS_PREFLIGHT_DIR=$t/run
KS_STACK_RUNTIME=podman; KS_STACK_DIRS=(kn-nginx kn-nginx/log); KS_STACK_CHECKS=("kn-nginx|nginx -t")
trap '"'"'echo "$BASH_COMMAND" >> "$t/trapped"; exit 1'"'"' ERR; set -E      # as the role runs it
have=1; says=0      # (not rc: the function asked has a local of that name)
timeout() { shift; "$@"; }      # the real one would run the real podman, not the stand-in
podman() {
    case $1 in
        image) (( have )) ;;
        run) shift; printf "%s\n" "$*" | sed "s#$t/run/kiwi-preflight\.[A-Za-z0-9]*#TMP#g; s#$t#T#g" > "$t/asked"
             for a in "$@"; do [[ $a == *"/new/kn-nginx/nginx.conf:"* ]] && cat "${a%%:*}" >> "$t/asked"; done
             echo "nginx: [emerg] unknown directive"; return $says ;;
    esac
}
asked() { if [[ -e $t/asked ]]; then cat "$t/asked"; rm -f "$t/asked"; else echo "not asked"; fi; }
echo "-- no image here"; have=0; ks_stack_preflight; asked; have=1
echo "-- switched off"; KS_NO_PREFLIGHT=1 ks_stack_preflight; asked
echo "-- it takes them"; ks_stack_preflight; asked
echo "-- the question failed"; says=125; ks_stack_preflight 2>&1; rm -f "$t/asked"
echo "-- it says no"; says=1; (ks_stack_preflight) 2>&1 || echo "stopped ($?)"; rm -f "$t/asked"
echo "left behind: $(ls "$t/run" | wc -l), on the machine still: $(cat "$t/stack/kn-nginx/nginx.conf")"
echo "-- nothing of it changes"; cp "$t/b/kn-nginx/nginx.conf" "$t/stack/kn-nginx/nginx.conf"; ks_stack_preflight; asked
echo "-- only its quadlet changes"; echo "# x" >> "$t/q/kn-nginx.container"; says=0; ks_stack_preflight; asked | head -n 1 | cut -c1-25
echo "-- an image without a shell"; KS_STACK_CHECKS=("kn-nginx|exec /sbin/prog configtest -c /f"); ks_stack_preflight; asked | head -n 1 | grep -o -- "--entrypoint.*"
' _ "$tmp/pf" 2>&1)
[[ ! -s $tmp/pf/trapped ]] || { echo "the role's error trap fired in the pre-flight: $(cat "$tmp/pf/trapped")"; exit 1; }
[[ $out == "-- no image here
not asked
-- switched off
not asked
-- it takes them
--rm --network none --sysctl net.ipv4.ip_nonlocal_bind=1 --security-opt label=disable -e KIWI_CHECK=1 -v TMP/new/kn-nginx/nginx.conf:/etc/nginx/nginx.conf:ro -v TMP/new/kn-nginx/privkey.pem:/etc/nginx/privkey.pem:ro -v T/stack/kn-nginx/acme:/etc/nginx/acme:O -v TMP/empty/kn-nginx/log:/var/log/nginx:O --add-host cloud.home:10.1.0.5 --entrypoint sh nginx:1 -c nginx -t
new config
-- the question failed
warning: kn-nginx could not be asked about its new settings (exit 125): nginx: [emerg] unknown directive
-- it says no
nginx: [emerg] unknown directive
error: kn-nginx would not start with its new settings (its own words above). The stack was not touched: every service runs as before. Correct the setting and apply again
stopped (1)
left behind: 0, on the machine still: old config
-- nothing of it changes
not asked
-- only its quadlet changes
--rm --network none --sys
-- an image without a shell
--entrypoint /sbin/prog nginx:1 configtest -c /f" ]] || { echo "pre-flight:"; echo "$out"; exit 1; }
# systemd reads its units again only when one was written or removed, and a unit is enabled only
# when it is not yet: `systemctl enable` makes systemd read everything again each time
mkdir -p "$tmp/rl/units" "$tmp/rl/run"
out=$(bash -c '
set -euo pipefail
. ./lib.sh
d=$1; me=$(id -un):$(id -gn); KS_SYSTEMD_DIR=$d/units; KS_RELOAD_MARK=$d/run/units-read
said=()
systemctl() {
    case "$*" in
        daemon-reload) said+=(reload) ;;
        "is-enabled -q on.service"|"is-active -q on.service") return 0 ;;
        "is-enabled -q "*|"is-active -q "*) return 1 ;;
        *) said+=("$*") ;;
    esac
}
ks_write() { mkdir -p "$(dirname "$1")"; cat > "$1.tmp"; ks_put "$1.tmp" "$1" "${2:-0644}" "$me"; }
show() { echo "$1: ${said[*]:-nothing}"; said=(); }
ks_reload; show "nothing written"
ks_unit a.service <<<"[Unit]"; show "a unit written"
ks_unit a.service <<<"[Unit]"; show "the same again"
ks_reload all; show "all, after its own reload"
sleep 1.1; echo x > "$d/units/foreign.service"; ks_reload all; show "all, after someone else wrote a unit"
ks_reload all; show "all again"
ks_enable on.service; show "enable one that is"
ks_enable --now on.service; show "enable --now one that is and runs"
ks_enable off.service; show "enable one that is not"
ks_enable --now off.timer; show "enable --now one that is not"
ks_disable off.service; show "disable one that is not there"
ks_disable --now on.service; show "disable --now one that runs"
' _ "$tmp/rl" 2>&1)
[[ $out == "nothing written: nothing
a unit written: reload
the same again: nothing
all, after its own reload: nothing
all, after someone else wrote a unit: reload
all again: nothing
enable one that is: nothing
enable --now one that is and runs: nothing
enable one that is not: enable -q off.service
enable --now one that is not: enable -q off.timer start off.timer
disable one that is not there: nothing
disable --now one that runs: disable -q --now on.service" ]] || { echo "reloads:"; echo "$out"; exit 1; }
# Debian's package lists are fetched once a day, not with every apply; an install still fetches them
mkdir -p "$tmp/apt"
out=$(bash -c '
set -euo pipefail
. ./lib.sh
KS_STATE_DIR=$1; KS_OS=debian
apt-get() { echo "apt-get ${*: -1}"; }
ks_apt_fresh; echo "-- again"; KS_APT_UPDATED=0; ks_apt_fresh
echo "-- a day later"; touch -d "25 hours ago" "$KS_STATE_DIR/apt-lists"; ks_apt_fresh
echo "-- an install of something missing"; KS_APT_UPDATED=0; dpkg-query() { return 1; }; ks_apt some-package | tr "\n" " "
' _ "$tmp/apt" 2>&1)
[[ $out == "apt-get update
-- again
-- a day later
apt-get update
-- an install of something missing
apt-get update apt-get some-package " ]] || { echo "apt lists:"; echo "$out"; exit 1; }
# firewalld is asked over D-Bus (busctl), and only what is missing is added with firewall-cmd; where
# busctl does not answer, firewall-cmd is asked as before. Under the role's error trap
mkdir -p "$tmp/fw"
out=$(bash -c '
set -euo pipefail
. ./lib.sh
t=$1; KS_STACK_RUNTIME=podman; KS_STACK_MESH_SUBNET=10.9.0.0/16; KS_STACK_MESH_VIA=kn-vpn-client
trap '"'"'echo "$BASH_COMMAND" >> "$t/trapped"; exit 1'"'"' ERR; set -E
bus=1
systemctl() { return 0; }; ks_say() { echo "say: $*"; }
ks_stack_subnets() { printf "172.128.0.0/24\n172.129.0.0/24\n"; }
busctl() {
    (( bus )) || return 1
    case "$*" in
        *getDefaultZone*) echo "s \"FedoraServer\"" ;;
        *getZoneByName\ s\ trusted*) echo "o \"/org/fedoraproject/FirewallD1/config/zone/10\"" ;;
        *getZoneByName\ s\ FedoraServer*) echo "o \"/org/fedoraproject/FirewallD1/config/zone/0\"" ;;
        *zone/10*getSources*) echo "as 2 \"10.9.0.0/16\" \"172.128.0.0/24\"" ;;
        *zone/0*getPorts*) echo "a(ss) 1 \"80\" \"tcp\"" ;;
        *FirewallD1.zone\ getSources\ s\ trusted*) echo "as 1 \"172.128.0.0/24\"" ;;
        *FirewallD1.zone\ getPorts\ s\ FedoraServer*) echo "aas 2 2 \"80\" \"tcp\" 2 \"443\" \"tcp\"" ;;
        *) echo "as 0" ;;
    esac
}
firewall-cmd() {
    case "$*" in
        *--list-sources*) [[ $* == *--permanent* ]] && echo "10.9.0.0/16 172.128.0.0/24 172.129.0.0/24" || echo "172.128.0.0/24 172.129.0.0/24 10.9.0.0/16" ;;
        *--list-ports*) echo "80/tcp 443/tcp" ;;
        *--get-default-zone*) echo public ;;
        *) echo "firewall-cmd $*" ;;
    esac
}
echo "-- over D-Bus"; ks_firewall_trust_stack; ks_fw_trust_mesh_source; ks_firewall_open 80/tcp 443/tcp
echo "-- without it"; bus=0; ks_firewall_trust_stack; ks_fw_trust_mesh_source; ks_firewall_open 80/tcp 443/tcp
' _ "$tmp/fw" 2>&1)
[[ ! -s $tmp/fw/trapped ]] || { echo "the error trap fired in the firewall steps: $(cat "$tmp/fw/trapped")"; exit 1; }
[[ $out == "-- over D-Bus
say: firewalld: the stack network 172.129.0.0/24 stays trusted across a reload
firewall-cmd -q --permanent --zone=trusted --add-source=172.129.0.0/24
firewall-cmd -q --zone=trusted --add-source=172.129.0.0/24
say: firewalld: the mesh 10.9.0.0/16 is trusted like the stack network
firewall-cmd -q --permanent --zone=trusted --add-source=10.9.0.0/16
firewall-cmd -q --zone=trusted --add-source=10.9.0.0/16
firewall-cmd -q --permanent --add-port=443/tcp
-- without it" ]] || { echo "firewall:"; echo "$out"; exit 1; }
# (without busctl, firewall-cmd's own lists: everything is there, nothing is added)
echo "kiwi-stack checks: ok"
