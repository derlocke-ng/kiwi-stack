# Files and variables

This page lists what kiwi-stack expects in a bundle and what it leaves on the
machine. kiwi-modules, kiwi-server and every machine that was already applied
rely on these names. A change to one of them breaks compatibility, so it is
checked against kiwi-server's stored test bundle first.

## The bundle

The file `stack.sh` is sourced by bash. It only sets variables whose names
start with `KS_`.

| Variables | What they say |
|---|---|
| `KS_HOST`, `KS_HOSTNAME`, `KS_DOMAIN`, `KS_TARGET`, `KS_ROLE`, `KS_ADMIN_USER`, `KS_TIMEZONE` | The machine: its names, its system, its role, its admin user and its time zone. |
| `KS_ROLE_PRESET`, `KS_ROLE_DOCKER_SOURCE`, `KS_ROLE_DAILY_VPN_RESTART`, `KS_ROLE_WEEKLY_UPDATE` | Settings of the role: the preset, where docker comes from, and the times of the two timers. |
| `KS_STACK=1` | The bundle has a stack. |
| `KS_STACK_DIR`, `KS_STACK_USER`, `KS_STACK_PREFIX`, `KS_STACK_RUNTIME` | The stack's directory, its service user, the prefix of its container names, and `podman` or `docker`. |
| `KS_STACK_MODULES`, `KS_STACK_SERVICES`, `KS_STACK_IMAGES`, `KS_STACK_QUADLETS`, `KS_STACK_UNITS` | The modules, the containers, their images, the unit files of the containers and the host units. |
| `KS_STACK_FILES`, `KS_STACK_DIRS` | Every file with its mode (`path:mode`), and the data directories. |
| `KS_STACK_PORTS`, `KS_STACK_SYSCTL`, `KS_STACK_KMODS` | The ports to open, the kernel settings and the kernel modules. |
| `KS_STACK_VPN_CONTAINER`, `KS_STACK_VPN_DEPENDENTS`, `KS_STACK_MESH_SUBNET`, `KS_STACK_MESH_VIA`, `KS_STACK_HOSTS`, `KS_STACK_DNS_IP`, `KS_STACK_NO_RESOLVED_STUB` | The network: the VPN client and what depends on it, the route into the mesh, the names for `/etc/hosts`, and the stack's resolver. |
| `KS_STACK_URLS` | The addresses to print after the start. |
| `KS_STACK_AUTO_UPDATE` | Whether images are updated from the registry. |
| `KS_SEED_ID`, `KS_SEED_FROM` | The short name of the seed, and of the seed it replaced when there is one. |

The files are at the paths named in `KS_STACK_FILES`, relative to the bundle.
Host units are in `host-units/`, the unit files of the containers in
`quadlets/`, and the CA certificate at `kiwi/ca/kiwiCA.crt`.

## On the machine

| Path | What it is |
|---|---|
| `/usr/local/bin/kiwi-stack`, `/usr/local/lib/kiwi-stack/lib.sh` | The command and its library. |
| `/etc/kiwi-server/stack.env` | What the command needs to know about the stack: `STACK_DIR`, `STACK_USER`, `STACK_RUNTIME`, `STACK_SERVICES`, `STACK_PREFIX`, `STACK_VPN_CONTAINER`, `STACK_VPN_DEPENDENTS`, `STACK_MESH_SUBNET`, `STACK_MESH_VIA`, `STACK_UNITS`, `STACK_MODULES`, `STACK_SEED_ID`, `STACK_AUTO_UPDATE`. |
| `/etc/containers/systemd/` | The unit files of the containers on podman. Each begins with the line `# kiwi-server stack` and has the mode `0600`. |
| `/etc/sysctl.d/90-kiwi-stack.conf` | The kernel settings. It begins with the same line. |
| `/etc/hosts` | The network's names, in a block between two marker lines that every apply replaces. The host resolves the other machines without asking a DNS server. |
| `kiwi-stack.service` | The unit that starts the stack. |
| `/var/lib/kiwi-server/role.done`, `role.failed`, `stack.applied` | Marks of the last apply: that the first setup finished, where an apply failed, and when a bundle was last applied. |
| `/var/log/kiwi-server-role.log` | The log of every apply. |

The names say `kiwi-server` because a machine installed by kiwi-server and a
machine applied by hand end up the same.
