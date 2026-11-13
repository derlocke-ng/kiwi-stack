# Bundle and machine contracts

This page lists what kiwi-stack reads from a bundle and what it leaves on the
machine. It is for people who write modules, change kiwi-modules or
kiwi-server, or look at a machine by hand.

These names are shared. [kiwi-modules](https://kiwi-network.eu/docs/server/modules/)
writes the bundle, [kiwi-server](https://kiwi-network.eu/docs/server/)'s role
scripts carry the same library, and every machine that was applied already has
the files below. A change to any of them is a compatibility break. It has to
change in all three places at once. kiwi-server's golden test compares a
rendered stack file by file, so a change to the bundle shows up there.

Some names on the machine say `kiwi-server`, for example
`/etc/kiwi-server/stack.env`. This is deliberate: the tools rely on these
names, so they are not renamed.

## The bundle

| Path in the bundle | What it is |
|---|---|
| `stack.sh` | The variables below, sourced by bash. |
| the paths in `KS_STACK_FILES` | The rendered files, at the same path below the stack directory. |
| `host-units/<unit>` | The host units in `KS_STACK_UNITS`. |
| `quadlets/<unit>` | The quadlets in `KS_STACK_QUADLETS`. |
| `kiwi/ca/kiwiCA.crt` | The network's CA certificate (optional). |

## The variables in stack.sh

`stack.sh` sets only `KS_*` variables. kiwi-modules writes all of the
following. Some are only read by a kiwi-server role script, which uses the
same list.

| Variable | Meaning |
|---|---|
| `KS_VERSION` | The renderer and its version; it appears in the log and in `stack.env`. |
| `KS_HOST`, `KS_HOSTNAME`, `KS_DOMAIN` | The machine's short name, full host name and domain. |
| `KS_TARGET` | The target system, for example `ucore`. |
| `KS_ROLE`, `KS_ROLE_PRESET` | The role, for example `master` or `node`, and its preset. |
| `KS_ADMIN_USER` | The admin user; on a docker stack it joins the `docker` group. |
| `KS_TIMEZONE` | The time zone. A role script sets it; `kiwi-stack apply` does not. |
| `KS_ROLE_DOCKER_SOURCE` | Where Debian gets docker: `ce` (Docker CE, the default) or `distro`. |
| `KS_ROLE_DAILY_VPN_RESTART` | The time (`HH:MM`) of the daily VPN client restart; empty for none. |
| `KS_ROLE_WEEKLY_UPDATE` | A systemd calendar time without seconds, for example `Sun *-*-* 00:00`; empty for no update timer. |
| `KS_ROLE_REGISTRY_MIRRORS` | An associative array from registry to mirror, for podman. |
| `KS_ROLE_APT_PROXY` | An apt proxy as `http://host:port`, for Debian. |
| `KS_STACK` | `1`: the role has a stack. |
| `KS_STACK_DIR` | The stack directory on the machine. |
| `KS_STACK_USER` | The service user that owns the data directories. |
| `KS_STACK_PREFIX` | The prefix of the container names, for example `kn`. |
| `KS_STACK_MODULES` | The modules in the stack. |
| `KS_STACK_DIRS` | The directories to create, relative to the stack directory or absolute. |
| `KS_STACK_PORTS` | The ports to open, as `port/proto`; a range is written `a-b`. |
| `KS_STACK_UNITS` | The host units' file names. |
| `KS_STACK_SYSCTL` | Sysctls as `key=value`. |
| `KS_STACK_KMODS` | Kernel modules to load. |
| `KS_STACK_FILES` | The rendered files as `path:mode`, relative to the bundle and to the stack directory. |
| `KS_STACK_SERVICES` | The container names; on podman also the unit names. |
| `KS_STACK_URLS` | Lines the apply prints at the end, usually the services' addresses. |
| `KS_STACK_VPN_CONTAINER` | The VPN client container, or empty. |
| `KS_STACK_VPN_DEPENDENTS` | The containers that share the VPN client's network namespace. |
| `KS_STACK_MESH_SUBNET`, `KS_STACK_MESH_VIA` | The mesh subnet and the container address the host routes it through. |
| `KS_STACK_HOSTS` | `IP name` lines for the block in `/etc/hosts`. |
| `KS_STACK_RUNTIME` | `podman` or `docker`. |
| `KS_STACK_QUADLETS` | The quadlets' file names. |
| `KS_STACK_NO_RESOLVED_STUB` | `1`: turn off systemd-resolved's stub listener. |
| `KS_STACK_IMAGES` | The images to pull before the first start. |
| `KS_STACK_DNS_IP` | The stack's Pi-hole address, or empty. |
| `KS_STACK_AUTO_UPDATE` | `registry` to let `kiwi-stack update` pull new images; anything else turns that off. |
| `KS_SEED_ID` | An identifier of the fleet seed that the secrets were derived from. |

## stack.env

The apply writes `/etc/kiwi-server/stack.env` (mode 0644), and the
`kiwi-stack` command reads it. It holds these keys: `STACK_DIR`,
`STACK_USER`, `STACK_RUNTIME`, `STACK_SERVICES`, `STACK_PREFIX`,
`STACK_VPN_CONTAINER`, `STACK_VPN_DEPENDENTS`, `STACK_MESH_SUBNET`,
`STACK_MESH_VIA`, `STACK_UNITS`, `STACK_FILES`, `STACK_MODULES`,
`STACK_SEED_ID` and `STACK_AUTO_UPDATE`. The next apply also reads it, to find
what the previous one installed.

## Files on the machine

| Path | What it is |
|---|---|
| `/usr/local/bin/kiwi-stack`, `/usr/local/lib/kiwi-stack/lib.sh` | The command and its library. |
| `/etc/kiwi-server/stack.env` | The stack's description, see above. |
| `/etc/systemd/system/kiwi-stack.service` | Starts the stack at boot with `kiwi-stack start` and stops it with `kiwi-stack stop`. |
| `/etc/systemd/system/kiwi-stack-vpn-restart.timer` and `.service` | The daily VPN client restart, when the stack asks for it. |
| `/etc/systemd/system/kiwi-stack-update.timer` and `.service` | The weekly `kiwi-stack update`, when the stack asks for it. |
| `/etc/systemd/system/` | The host units, and on podman the `kiwi-stack.target` quadlet. |
| `/etc/containers/systemd/` | The podman quadlets, mode 0600. Each contains the line `# kiwi-server stack`, and the next apply removes every quadlet with that line. |
| `/etc/sysctl.d/90-kiwi-stack.conf` | The stack's sysctls; the first line is `# kiwi-server stack`. |
| `/etc/sysctl.d/91-kiwi-mesh.conf`, `/etc/modules-load.d/kiwi-br_netfilter.conf` | Bridged container traffic tracked by the host, on a podman stack with a mesh. |
| `/etc/modules-load.d/kiwi-<module>.conf` | The stack's kernel modules. |
| `/etc/containers/containers.conf.d/50-kiwi-dns.conf` | podman's own resolver on port 5533, on a podman stack with a DNS server. |
| `/etc/containers/registries.conf.d/50-kiwi-mirrors.conf` | The registry mirrors. |
| `/etc/apt/apt.conf.d/30kiwi-proxy`, `/usr/local/bin/kiwi-apt-proxy` | The apt proxy, used while it answers. |
| `/etc/systemd/resolved.conf.d/90-kiwi-stack.conf` | systemd-resolved's settings for the stack's Pi-hole. |
| `/etc/hosts` | The network's names, between `# >>> kiwi-server fleet names >>>` and `# <<< kiwi-server fleet names <<<`. |
| `/etc/systemd/system/chrony-wait.service.d/90-kiwi.conf` or `systemd-time-wait-sync.service.d/90-kiwi.conf` | The 90-second limit for waiting for the clock at boot. |
| `/etc/pki/ca-trust/source/anchors/kiwiCA.pem` or `/usr/local/share/ca-certificates/kiwiCA.crt` | The network's CA certificate. |
| `/var/lib/kiwi-server/stack.applied` | The time of the last successful `kiwi-stack apply`. |
| `/var/lib/kiwi-server/role.failed` | Where the last apply stopped, while it has not succeeded since. |
| `/var/lib/kiwi-server/role.done` | Written by a kiwi-server role script, not by `kiwi-stack apply`. |
| `/var/log/kiwi-server-role.log` | The log of every apply. |

On a Debian machine with Docker CE, the apply also writes
`/etc/apt/keyrings/docker.asc` and `/etc/apt/sources.list.d/docker.list`. A
compose plugin that it downloaded is in `/usr/local/lib/docker/cli-plugins/`.
