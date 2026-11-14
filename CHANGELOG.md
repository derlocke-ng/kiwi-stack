# Changelog

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
