# kiwi-stack

The machine side of a kiwi stack: the `kiwi-stack` command and the library
that puts a rendered bundle onto a CoreOS, uCore or Debian machine and keeps
it running. The bundle comes from
[kiwi-modules](https://github.com/derlocke-ng/kiwi-modules) (`kiwi-modules
render machine.yaml -o DIR`, one machine, no fleet) or from
[kiwi-server](https://github.com/derlocke-ng/kiwi-server) (`output/<host>/<host>.stack/`);
a kiwi-server role script carries this same library and installs this same
command on first boot, so a machine set up either way ends up identical.

```sh
git clone https://github.com/derlocke-ng/kiwi-stack && cd kiwi-stack
sudo ./install.sh install          # /usr/local/bin/kiwi-stack, /usr/local/lib/kiwi-stack/lib.sh
sudo kiwi-stack apply /tmp/sh3.bundle
kiwi-stack status
```

Needs bash, systemd, and podman 4.4+ with catatonit (quadlets) or docker
with the compose plugin, whichever the bundle's `runtime` is. Runs as root.

## What apply does

`kiwi-stack apply DIR` sources `DIR/stack.sh` and, logged to
`/var/log/kiwi-server-role.log` with an error trap that leaves
`/var/lib/kiwi-server/role.failed` (step, command, last log lines) when a
step fails:

1. trusts the network's CA when the bundle carries one (`kiwi/ca/kiwiCA.crt`);
2. creates the service user, installs or enables podman or docker, loads
   kernel modules, applies sysctls, turns systemd-resolved's stub listener
   off when the stack runs a resolver and points resolved at it;
3. refuses a bundle from another seed than the one applied before
   (`KS_SEED_ID` against `STACK_SEED_ID` in `/etc/kiwi-server/stack.env`):
   the databases know the old passwords;
4. stops the old stack when the runtime or the directory changes, unpacks
   the bundle into the stack directory (data owned by the service user,
   rendered files root's, secrets 0600), installs the host units and the
   quadlets (`/etc/containers/systemd`, marked `# kiwi-server stack`, 0600),
   removes units a previous apply put there and the bundle no longer has;
5. installs itself (`/usr/local/bin/kiwi-stack`, the library) and writes
   `/etc/kiwi-server/stack.env`;
6. opens the ports in firewalld or ufw;
7. pulls every image with retries, enables and restarts `kiwi-stack.service`
   (the stack's target or `compose up`), the host units, the daily VPN
   restart and weekly update timers the stack asks for, then
   `kiwi-stack verify`: every container must be running, or the apply fails
   with their names.

An apply is repeatable: the same bundle again changes nothing, a new render
replaces what changed.

## The command

```
kiwi-stack start|stop|restart        the whole stack (kiwi-stack.service), then the host units
kiwi-stack status                    units or compose ps, the mesh route
kiwi-stack verify                    exit 1 with the names of containers that are not running
kiwi-stack logs [service]            journal or compose logs
kiwi-stack update                    pull newer images and restart (honours STACK_AUTO_UPDATE)
kiwi-stack vpn-restart               restart the VPN client and what depends on it (the daily timer runs this)
kiwi-stack apply DIR                 a bundle, as above
```

## The contracts

These are read by both repositories and by every machine already applied;
a change is a compatibility break and goes through kiwi-server's golden test.

**The bundle** (`stack.sh` sourced by bash, `KS_*` only): `KS_HOST`,
`KS_HOSTNAME`, `KS_DOMAIN`, `KS_TARGET`, `KS_ROLE`, `KS_ADMIN_USER`,
`KS_TIMEZONE`, `KS_ROLE_PRESET`, `KS_ROLE_DOCKER_SOURCE`,
`KS_ROLE_DAILY_VPN_RESTART`, `KS_ROLE_WEEKLY_UPDATE`, `KS_STACK=1` and the
`KS_STACK_*` list: `DIR`, `USER`, `PREFIX`, `MODULES`, `DIRS`, `PORTS`,
`UNITS`, `SYSCTL`, `KMODS`, `FILES` (`path:mode`), `SERVICES`, `URLS`,
`VPN_CONTAINER`, `VPN_DEPENDENTS`, `MESH_SUBNET`, `MESH_VIA`, `HOSTS`,
`RUNTIME`, `QUADLETS`, `NO_RESOLVED_STUB`, `IMAGES`, `DNS_IP`,
`AUTO_UPDATE`, plus `KS_SEED_ID`. Files: the paths in `KS_STACK_FILES`
relative to the bundle, `host-units/<unit>`, `quadlets/<unit>`,
`kiwi/ca/kiwiCA.crt`.

**On the machine:** `/etc/kiwi-server/stack.env` with `STACK_DIR`,
`STACK_USER`, `STACK_RUNTIME`, `STACK_SERVICES`, `STACK_PREFIX`,
`STACK_VPN_CONTAINER`, `STACK_VPN_DEPENDENTS`, `STACK_MESH_SUBNET`,
`STACK_MESH_VIA`, `STACK_UNITS`, `STACK_MODULES`, `STACK_SEED_ID`,
`STACK_AUTO_UPDATE`; the unit `kiwi-stack.service`; quadlets and
`/etc/sysctl.d/90-kiwi-stack.conf` begin with `# kiwi-server stack`;
`/var/lib/kiwi-server/{role.done,role.failed,stack.applied}`;
`/var/log/kiwi-server-role.log`.

## Status

0.2.0: `lib.sh` and the command as kiwi-server 2.7.0 embeds them, with the
fixes of the first hardware round (CHANGELOG.md); they have applied a master
and two nodes. kiwi-server is still where they are developed; its
`tools/split-sync.sh` copies them here and checks for drift, until this
repository is vendored back.

## License

GPL-3.0-or-later.
