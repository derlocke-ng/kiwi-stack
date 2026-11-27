# Changelog

## 0.9.42 — a question for an image without a shell

- `KS_STACK_CHECKS`: a command written as `exec PROGRAM ARGS` runs the program itself in the
  throwaway container, without `sh -c`. Kanidm's image has no shell, and its own config test
  (`kanidmd configtest`) could not be asked.

## 0.9.41 — verify names a service that runs but is not well

- `kiwi-stack verify` (and so the end of every apply, and `kiwi-stack status`) names the
  stack's containers that run and fail their own health check: "unhealthy (it runs, and its
  own check fails): kn-vault". It is no failure by itself: an apply that changed something
  else does not fail for a part that hangs since yesterday. A container the apply just
  restarted is "starting" and is not named.

## 0.9.40 — a part is asked before its new files are written

- **`KS_STACK_CHECKS`** (`container|command`): before an apply writes anything of the stack, the
  command runs in a throwaway container made like the named one will be: its image, its mounts,
  its names, no network, nothing it writes kept. The files the apply brings are mounted from a
  copy, the rest from the machine. A command that fails stops the apply there: "kn-nginx would
  not start with its new settings", with the part's own words, and every service runs as
  before. Until now an nginx that refused its config was found when it did not start again,
  with every site of the machine gone. Not asked when the image is not on the machine yet or
  when nothing of that container changes (no cost for an apply that leaves it alone); a
  question that fails by itself (podman, time) is a warning. Podman only.
  `KS_NO_PREFLIGHT=1` leaves the questions out.

## 0.9.39 — no false alarm from a unit that names no script

- 0.9.38's look for a unit's own files failed in a subshell for every unit that names no script
  under `kiwi/`, and the role's error trap printed "the role stopped … in ks_unit_claims" for
  each. The role went on and ended well, and the units were judged right, but the lines read
  like a failed apply (seen on a master with eight such units, 27 Nov 2026).

## 0.9.38 — a part's script runs again when its own files changed

- 0.9.37 started all of the stack's units again for any change in the stack. A setting of one
  part then restarted a gateway's routes too. A unit now starts again when a file of its own
  changed: the unit, a script it runs, a file beside the script of the same name
  (`cloud-accounts.sh` and `cloud-accounts.env`) or in a folder of that name (`backup/`). A
  changed file under `kiwi/` that no unit claims starts them all, to be sure, as does a start
  from nothing or an apply that ended before its units ran; a unit that is not fine starts
  alone. A restarted container is no reason.
  Tried on a gateway with the accounts: a vault's setting restarted the vault's container and
  left four units; the accounts' password length ran the accounts' script and left the other
  three.

## 0.9.37 — a quicker role

Measured on a machine with 34 containers, a gateway and 15 open ports (papaya, 27 Nov 2026): the
role of an apply that changes nothing went from 70 to 38 seconds.

- **The stack's units start again only when there is a reason**: something of the stack changed
  (a file, a quadlet, a unit), a container restarted, the stack started from nothing, or a unit
  is not fine. An apply that changed nothing restarted them all: 17 seconds there, a gateway's
  routes gone for a moment, and a backup started. A timer's service counts as fine while its
  timer runs.
- **The stack-only path runs the units too** when something changed. Until now it left them, and
  a setting that a part's own script applies (shared folders, a sign-in set-up) waited for the
  next full apply.
- **firewalld is asked once** which ports are open; only missing ones are added. Four questions
  a port took 12 seconds with 15 ports.
- **A file that is there already as it should be is left alone**: no rewrite, no sync, the same
  inode. A unit that did not change costs no reload of systemd (fifteen a run before).
- The stack's target was looked for among the quadlets and counted as changed at every apply.
- `KS_TIMES=1` (kiwi-server: `KIWI_APPLY_TIMES=1`): each step of the role with its time, and the
  names of the files that changed. Names only, never a value.

## 0.9.36 — the role's log is root's alone, and never a trace

- `/var/log/kiwi-server-role.log` was readable by every user of the machine. It is root's alone
  now (0600), set at every run.
- A role or stack script run under `bash -x` switches the trace off before its output goes into
  that log: the script carries the stack's files (keys, passwords) in its variables, and a trace
  would write them all there (27 Nov 2026, a timing trace on a test machine).

## 0.9.35 — a new name restarts nothing

- A new site on a machine gives every container one more name (an `AddHost` line in its
  quadlet), and until now every one of them restarted for it: adding a vault to a machine
  restarted the eleven containers of its Nextcloud (27 Nov 2026). A quadlet that changed in
  nothing but these lines no longer restarts its container: the names are written into the
  running container's hosts file, in place, and are there at once; names that went are taken
  out. Whatever else changed in a quadlet restarts as before. Names an apply did not get to hand
  over (it ended before) become a restart at the next one. Tried on a uCore machine: a third
  site added and taken away again, the proxy restarted, eleven containers kept running and
  resolved the name.

## 0.9.34 — an apply no longer cuts the containers' DNS

- On a Podman machine with firewalld, every apply reloaded firewalld to open the stack's ports.
  The reload dropped the stack network from the trusted sources (netavark adds it to the running
  configuration only, when a container starts), the containers could no longer ask their DNS, and
  two minutes later the reverse proxy answered 502 for every site until a restart. Seen on a
  machine without the gateway module, which already kept that source. Ports go into the permanent
  and the running configuration now, without a reload.
- The stack network is kept as a permanent trusted source, so a reload by anything else does no
  harm either; an apply puts it back on a machine a reload already hit.

## 0.9.33 — updates run again

- `kiwi-stack update` called the backup module's script without its `backup` verb, so the script
  printed its usage, the backup before the update counted as failed and nothing was updated on
  any machine with a backup module since 0.9.31. It asks for a backup now; tests/check.sh runs
  that call against a stand-in script.

## 0.9.32 — only the stack

- A role script run with `--stack-only` does only the stack's steps: the fleet's names in
  /etc/hosts, the stack's files and quadlets, a restart of what changed, the check that every
  container runs. kiwi-server sends it so when nothing else of the machine changed (a part's
  settings, the network's names): seconds instead of minutes. Without a stack on the machine yet,
  the whole role runs as before.

## 0.9.31 — a backup before an update

- `kiwi-stack update` (an apply with `--update`, and the weekly update) makes a backup first, on a
  machine that has the backup module. When the backup fails, nothing is updated.
  `KIWI_UPDATE_NO_BACKUP=1` leaves it out.

## 0.9.30 — the role script does not stay

- The role script (`/var/lib/kiwi-server/role.sh`) carries every secret of its machine. It removes
  itself once it has done its work: nothing reads it again (an apply sends a fresh copy, the version
  is in stack.env). One that failed stays, for the next boot's try; a copy run from elsewhere is left.

## 0.9.29 — parts that run by a permission

- `kiwi-stack lease [list|start|stop] [CONTAINER...]`: the containers of this machine's parts that
  have a standby (`STACK_LEASED`, kiwi-modules 0.116.0). They run only while the machine holds a
  permission for them; kiwi-server's `kiwi-lease` calls this.
- An apply leaves them to that permission: `verify` does not count them as down, a changed one is
  restarted only when it runs (`try-restart`), docker gets them made, and `kiwi-lease tick` runs at
  the end of the apply. The daily VPN restart restarts one only when it runs.

## 0.9.28 — a part this machine no longer runs stops

- **Fixed: a machine a part was switched away from kept running it after its apply**, now that it
  keeps the part ready (kiwi-server's pair): its containers moved from `KS_STACK_SERVICES` to
  `KS_STACK_READY`, which no apply stopped. The apply stops one that runs, before the standby's
  fetch writes under it.

## 0.9.27 — the proxy with the ready parts' sites

- `kiwi-stack ready start` puts the proxy's config with the sites of the parts kept ready in
  place (kiwi-modules' `nginx-ready.conf`, written over `nginx.conf` in place) and reloads it, so
  their names answer at once; a config nginx refuses is put back as it was.

## 0.9.26 — parts kept ready for another machine

- `KS_STACK_READY` (kiwi-modules 0.112.0): the containers of a part this machine keeps ready for
  another one. Their images are pulled with the others, docker makes their containers (profile
  `kiwi-ready`), podman has their quadlets without `[Install]`; nothing an apply or a restart does
  starts them. `kiwi-stack ready list|start|stop [CONTAINER...]`: kiwi-server's switch starts them.

## 0.9.25 — the time from the network

- A machine asks the time servers its stack names (`KS_STACK_NTP`: its site's Pi-hole, else the
  master's) first, the public pool behind them: a drop-in for timesyncd (which takes its
  fallbacks only when no server is named, so the pool is named after them), or `server … iburst
  prefer` lines at the top of chrony.conf between kiwi-server's markers. None named: the
  drop-in and the lines go again.
- The groups of the home network may always ask the time (udp 123), as they may always ask DNS.

## 0.9.24 — the host's second resolver answers every name

- While the stack runs, the host asks its own Pi-hole and, behind it, a public resolver: that
  one is Cloudflare's now (1.1.1.1, 1.0.0.1), not Quad9's, which leaves out names it holds to be
  malicious. What is blocked is what the network's blocklist says.

## 0.9.23 — a unit's state without its log

- `kiwi-stack status` (and so `kiwi-server status`) shows each host unit's state without its
  journal lines: a timer's last run (the ACME client's output) filled the status. A failed unit
  still shows its last 10 lines, which say why it failed.

## 0.9.22 — a quieter status

- `kiwi-stack status` (and so `kiwi-server status`) leaves out podman's
  `conmon … <nwarn>: Failed to open cgroups file` lines: conmon writes one for every exec into a
  container under systemd (a health check, a cron run), and in a unit's status they hid
  everything else. Nothing else is left out.

## 0.9.21 — only the container whose image changed

- **Fixed (0.9.20):** making room on a full disk compared the images' full IDs with the short
  ones `podman ps` shows, so every container of the stack counted as changed: on crumble all
  seven stopped, their images went and came back at the start (a minute without the master's
  VPN). Both are compared by their first 12 hex digits now: only a container whose image the
  stack no longer names goes. The check's fake podman shows IDs as podman does, and fails
  against 0.9.20.

## 0.9.20 — room for a changed image on a full disk

- An apply that changes a container's image (nginx:1 to nginx:1-alpine) pulled the new one while
  the container still held the old: on a master in RAM (crumble: 55 MB free of 913 MB) the pull
  failed and the apply stopped (safely: nothing had changed). With the disk 85 % full or more, a
  container of the stack whose image it no longer names stops (its unit first) and goes with its
  image before the pull; the units bring it back on the new one.
- tests/check.sh: two checks that could not fail (`! grep` does not stop a `set -e` script) fail
  now when they should.

## 0.9.19 — a tagged interface at boot

- `kiwi-vlans.service` runs before the network, when the card may still be down: a tagged
  interface cannot come up then ("Network is down"), and the unit failed although the kernel
  brought the interface up with its card a moment later. The script brings the card up first.
  Seen on a Debian test machine after a restart.

## 0.9.18 — tagged interfaces (VLANs)

- `kiwi-stack apply` makes the machine's tagged interfaces (`KS_STACK_VLANS`: "ID ADDRESS
  [CARD]", kiwi-modules 0.98.0, kiwi-server docs/design/lans.md step 2): `eth0.20` on the card
  named, or on the card of the default route, with its address and no default route
  (`vlan20` where the name would be too long). `kiwi-vlans.service` makes them again at boot,
  after their card and before the network and the containers. A VLAN that is gone or changed
  loses its interface first. Without VLANs the interface, `/etc/kiwi-server/vlans` and the unit
  are gone. A bundle from before has none and changes nothing.
- Proven in kiwi-server's `tests/drills/vlan-netns.py`: a switch with VLAN filtering, the node
  on a trunk, a device on an access port of VLAN 20 reaches it there, an untagged device with
  an address of VLAN 20 does not.

## 0.9.17 — the groups of the home network

- `kiwi-stack apply` keeps what each group of the home network may open on this machine
  (`KS_STACK_LAN_RULES`, kiwi-modules 0.96.0, kiwi-server docs/design/lans.md) in the nftables
  table `kiwi_lan`: per group all, nothing, or some ports; only what is addressed to this
  machine is looked at, before a published port's DNAT; DNS, DHCP and ping stay open, and
  answers to what the machine started come back. The rules are checked (`nft -c`) before they
  replace the old ones in one transaction, and `kiwi-lan.service` loads them at boot. Without
  groups the table is gone.

## 0.9.16 — an update with little room

- `kiwi-stack update` on a nearly full disk (75 % or more where the images are) takes one image at
  a time: it pulls it, restarts what runs it and drops the old copy before the next. `podman
  auto-update` pulls every new image first, and a master in RAM (crumble: 95 % with its own
  images) had no room for that.

## 0.9.15 — an apply asks only for what is missing

- An apply pulls only the images the machine does not have yet; newer ones come with the update
  (the weekly timer, `kiwi-stack update`, `kiwi-server apply --update`). A settings change on
  papaya asked 31 registries each time, and a registry out of reach (codeberg.org on medlar)
  cost three tries. With `auto_update: off` the apply still asks for every image, as it is the
  only way they change there.
- Packages that are installed already are not looked up again: no `apt-get update` at every
  apply.

## 0.9.14 — images nothing uses go when the disk runs full

- After an apply the stack drops the old copies of its images, and when the disk under them is
  75% full or more also every image that no container and no module of the stack uses. A master
  in RAM (913 MB for /var) had filled it to 95%, 145 MB of it images of modules it no longer ran.

## 0.9.13 — verify with a game server asleep

- 0.9.12's `verify` said every container ran, then failed: its last look (is a container
  reached on the stack's network) asked podman about the sleeping server, whose container does
  not exist while it sleeps, and under `set -e` that ended it. An apply then called the stack
  not up (medlar, 18 Nov 2026). A container asleep is left out of that look now; the test calls
  `verify` the way `kiwi-stack verify` runs it.

## 0.9.12 — asleep is not down

- `verify` and `status` count a service with a file in `/run/kiwi-stack/sleeping/` as asleep,
  not as down: a game server that the games module stopped while nobody plays on it, and
  starts again for the first player. One stopped without that file is still down.

## 0.9.11 — the owed restarts say nothing when none are owed

- 0.9.10's look for owed restarts read a file that is usually not there; under the role
  script's error trap that printed "the role stopped" although the apply went on, and the list
  of restarts could come out empty. It checks for the file first now; the checks run it under
  the same trap.

## 0.9.10 — a restart an apply owes is not forgotten

- What an apply changed and has not restarted yet is written down
  (`/etc/kiwi-server/restart-pending`) before the images are pulled, and only cleared once it
  restarted. An apply that ended at a pull (a master in memory out of room, 17 Nov 2026) had
  written its files; the next run found them the same, restarted nothing, and the old VPN
  server went on with the old settings.

## 0.9.9 — a power cut during an apply leaves whole files

- Each file an apply replaces is on the disk before it takes the old one's place, and the
  rename is too. A power cut in the middle of an apply leaves the old file or the new one,
  never an empty one (XFS, the root of Fedora CoreOS, keeps nothing back for a rename).
  0.9.7 had made sure of it at the end of an apply only.

## 0.9.8 — a removed service leaves no failed unit behind

- A service that no module runs any more is stopped and removed, as before; its failed
  state is cleared too. A service that ended with an error on its way out (seen with a
  Jabber server moved to another machine) stayed listed under the machine's failed units
  though nothing was wrong.

## 0.9.7 — what an apply wrote survives a power cut

- After the stack is written and started, and at the end of the role, the machine's
  files are forced to the disk. Before, a power cut in the minute after an apply could
  bring the stack's files back empty (seen with kiwi-server's control node, whose files
  were written the same way).

## 0.9.6 — the file in /run has a name of its own

- 0.9.5 wrote the running stack's DNS setting to `/run/systemd/resolved.conf.d/` under
  the name of the file in `/etc`, which hides it: the machine did not ask its Pi-hole at
  all. It is `91-kiwi-stack-dns.conf` now.

## 0.9.5 — a machine with its own Pi-hole has somebody to ask at boot

- The machine asks its own Pi-hole only while the stack runs (`/run/systemd/resolved.conf.d`,
  set by `kiwi-stack up`, taken away by `stop`). Set for good, it had nobody to ask at
  boot until the stack was up: the time service could not find its servers by name, and
  the stack, which waits for the clock, started 90 seconds late.
- The wait for the clock ends after 90 seconds without counting as a failed unit.
  `chrony-wait.service` ran into systemd's timeout at every boot of such a machine, and
  `status` showed "failed units: chrony-wait.service" on a machine that had no problem.

## 0.9.4 — systemd-networkd leaves the stack's routes and rules alone

- Where systemd-networkd runs the network (Armbian), it removed routes and routing rules
  it had not made whenever it set a card up anew. The stack's route to the mesh and the
  gateway's rule for LAN clients vanished with a new address or a link that came back,
  until the stack was restarted. `ManageForeignRoutes=no` and
  `ManageForeignRoutingPolicyRules=no` are set once.

## 0.9.3 — the cache script is put right before the first apt

- The script that sends apt to the LAN's cache is written before the first `apt-get` of
  a run, not after it: a machine with the older script could not get past its own apt
  to receive the new one.

## 0.9.2 — packages on an Armbian board behind the LAN's cache

- Only Debian's own sources go through the LAN's package cache. Every other source
  (Armbian's own, a vendor's) goes direct: the cache keeps Debian only and answered 403,
  so `apt-get update` failed and nothing could be installed on a board.

## 0.9.1 — what an Odroid met as the home's gateway

- `kiwi-stack address` said "not run by systemd-networkd" on a machine that is: the
  check piped into `grep -q`, and `pipefail` counted its early exit.
- Debian and Armbian with podman: `iptables` is installed when it is missing. The
  gateway's routing script needs it, and Armbian's image has nft only.
- `kiwi-stack verify` names a container whose address the machine routes somewhere else
  than to the stack's own network: a router that hands out a route for that address
  (seen: 172.128.0.4 via another gateway) leaves the container without a network, and
  nothing said why. A fixed address for the machine ends it.

## 0.9.0 — a board gets its fixed address

- `kiwi-stack address ADDRESS/PREFIX GATEWAY [DNS...]`: this machine's fixed address at
  home, where systemd-networkd runs the network (Armbian). A board starts from an image
  and asks the router; until now the address in the fleet file never reached it. The
  new address is checked (the card has it, the router is there, nobody else uses it);
  when it does not work, what the machine had before is back within a minute.
  `kiwi-stack address` alone says what the machine has. kiwi-server runs it after an
  apply.
- The dns module added to a machine whose stack already runs (podman): Pi-hole did not
  start, "address already in use", because podman's own resolver kept port 53 until
  its network was empty. The stack now stops once and starts from the beginning when
  the resolver's port is moved.

## 0.8.3 — system updates work behind the LAN's image cache

- A uCore machine that fetches its images through the LAN's cache never got a system
  update: the update checks the image's signature where it fetches it, the cache counted
  as a place without signatures ("A signature was required, but no signature exists"),
  and `rpm-ostreed-automatic.service` stayed failed. The cache is now named as a place
  that carries signatures (`/etc/containers/registries.d/50-kiwi-mirrors.yaml`).

## 0.8.2 — a setup right after a Debian install waits for apt

- A fresh Debian fetches its own package lists after its first boot and holds their lock.
  An apply started in that minute stopped at `apt-get update`. It waits for the lock now.

## 0.8.1 — a docs/ folder, and a short README

- `docs/`: install and supported systems, every command, what an apply does, the files and
  variables, development. kiwi-network.eu shows these pages from the next release on.
- The README is the short front page now; it had not named `backup`, `snapshots` and
  `restore`.

## 0.8.0 — a replaced seed is taken when the bundle says so

- A bundle from another seed than the running stack's is still refused, unless it names the
  running one as the seed it replaced (`KS_SEED_FROM`, kiwi-modules 0.30.1): kiwi-server's
  `rotate seed` replaces the secrets that containers read at every start, and those
  containers restart.

## 0.7.1 — minimal Debian and Armbian

- nftables comes with podman: netavark needs `nft`, which a minimal Debian (a cloud image,
  Armbian minimal) does not have. Found on an arm64 node.
- Docker CE from Docker's Ubuntu repository on Ubuntu and Ubuntu-based Armbian.

## 0.7.0 — the LAN's cache first

- `KS_ROLE_REGISTRY_MIRRORS` (registry → mirror) becomes podman's
  `registries.conf.d/50-kiwi-mirrors.conf`: the mirror first, the registry itself when it does
  not answer. `KS_ROLE_APT_PROXY` becomes apt's `Proxy-Auto-Detect` script on Debian: the
  proxy while it answers, else direct. Both go away again when the settings are empty.

## 0.6.2 — verify waits for the containers that follow

- `kiwi-stack verify` asks again for a minute before it calls a container down: the containers
  sharing a restarted container's network follow it a few seconds later, and an apply that
  restarted the WireGuard server failed its check although everything came up.

## 0.6.1 — an apply leaves a data directory's owner alone

- An apply set every existing data directory to the stack user, also one its container owns
  as another (Tang runs as 999). Every container restarted at every apply then and put its
  owner back; since 0.6.0 restarts only what changed, Tang could not read its keys after an
  apply and answered 500. Only a directory owned by root is changed now.
- An image that cannot be pulled, its registry down, no longer stops an apply when the
  machine has a copy of it: it warns and goes on.

## 0.6.0 — an apply restarts only what changed

- On a running podman stack an apply restarts only the containers whose quadlet changed, or
  a file they mount or read (`Volume=`, `EnvironmentFile=`), and starts what is new; the rest
  goes on serving. It restarted every container before (problem 55), and on a master that
  dropped every VPN client. A container in another's network follows it by its binding. The
  first apply, a stopped stack and a recreated network still start everything.
- `kiwi-stack up`: start what is not running, without touching what is or the host units.

## 0.5.0 — what a module leaves behind goes with it

- An apply removes the files a module rendered once it has left the stack, as it already did
  with its host units. A backup script left behind still looked like a configured backup to
  `kiwi-server status`, which would have called it late after a day and a half. The list is
  kept in stack.env from this release on; what earlier ones left stays.

## 0.4.0 — docker goes when the stack has left it

- On a podman machine an apply switches off a Docker daemon that runs nothing, and warns if it
  does run something. Docker sets iptables' FORWARD policy to DROP at every start, which kept
  the machine's published ports from the network after a reboot while every container looked
  healthy: found on a node that had tried `runtime: docker` and gone back, when another
  machine's nightly backup could no longer reach it.

## 0.3.0 — backups have a verb

- `kiwi-stack backup`, `snapshots` and `restore MODULE...` run the script the backup
  module of kiwi-modules puts on the machine, and say so on a machine without it.

## 0.2.4 — behind chrony, wait with chrony

- A stack with a VPN client uses `chrony-wait.service` where chronyd runs.
  `systemd-time-wait-sync` only wakes when the clock is stepped or timesyncd says
  so, and chrony trims a clock that is already close, so on uCore it sat out its
  whole 90 seconds at every boot and failed (kiwi-server problem 62). Measured on
  a mini PC: 94 seconds of userspace boot before, 25 after, and the stack still
  starts after the clock is good.

## 0.2.3 — a VPN client waits for the clock at boot

- `kiwi-stack.service` starts after `time-sync.target`, and a stack with a VPN
  client enables `systemd-time-wait-sync`, bounded at 90 seconds so a machine
  without NTP still comes up. WireGuard ignores a handshake older than the
  newest it has seen from that peer: a machine that booted with its clock
  ahead and opened its tunnel before NTP stepped the clock back was shut out
  of the mesh, in silence, until real time caught up (kiwi-server problem 60).

## 0.2.2 — bridged traffic tracked on every podman host with a mesh

- `ks_firewall_trust_mesh` loads `br_netfilter` and sets
  `bridge-nf-call-iptables` on every podman host that routes a mesh through
  the stack, not only where firewalld runs: netavark's own forward chain
  drops the untracked reply of a DNAT'd mesh connection as invalid (seen on a
  Debian node without any firewall; kiwi-server 2.7.1, problem 57).

## 0.2.1 — the mesh trusted on a firewalld host

- `ks_firewall_trust_mesh`: with firewalld active and a mesh routed through
  the stack, `br_netfilter` is loaded, `bridge-nf-call-iptables` set and
  persisted, and the mesh subnet added to the trusted zone — a mesh client's
  DNAT'd connection to a service answered through the host, whose conntrack
  saw only the reply (kiwi-server 2.7.1, problem 57, found with the first
  device).

## 0.2.0 — what the first hardware round found

`lib.sh` and the command as kiwi-server 2.7.0 embeds them. Found on
30 October 2026 on the first master and the first gateway+cloud node:

- **The first boot waits for name resolution** (two minutes at most) before
  its first apt or pull: `network-online.target` is satisfied before the
  resolver is, and apt had failed with "Temporary failure resolving".
- **The first podman apply on a fresh machine no longer fails** in the
  quadlet cleanup (a grep over empty globs exited 2 under `pipefail`);
  `role.failed` names the function the failing command sat in.
- **A changed `.network` quadlet gets its network recreated**: the apply
  stops the stack, removes the podman network and stops the quadlet's
  oneshot unit, which stays "active (exited)" and would not run again.
- **podman's own resolver moves off port 53** (`dns_bind_port` in
  `containers.conf.d`) when the stack runs one, so Pi-hole may publish it.

## 0.1.0 — the machine side carved out of kiwi-server

The `kiwi-stack` command and `lib.sh` as kiwi-server 2.6.0 embeds them,
unchanged, with `kiwi-stack apply DIR` for a bundle rendered by kiwi-modules,
an installer, and the contracts (stack.sh variables, stack.env keys, the
kiwi-stack.service unit, the quadlet marker) written down in the README.
Nothing here has run on hardware yet.
