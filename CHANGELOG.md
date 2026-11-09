# Changelog

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
