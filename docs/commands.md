# The kiwi-stack command

After an apply, the `kiwi-stack` command runs the stack on the machine: it
starts and stops it, shows its state, checks it, updates its images and runs
the backup module. Run it as root. Every command except `apply` reads
`/etc/kiwi-server/stack.env`, which the apply writes. On a machine without a
stack, these commands stop with "no stack on this machine yet".

## Commands

| Command | What it does |
|---|---|
| `kiwi-stack apply DIR` | Applies a bundle; see [Apply a bundle](apply.md). |
| `kiwi-stack start` | Starts the whole stack, sets the mesh route, and restarts the host units. |
| `kiwi-stack up` | Starts the containers that are not running and sets the mesh route. It leaves running containers and the host units alone. |
| `kiwi-stack stop` | Stops the host units and then every container of the stack. |
| `kiwi-stack restart` | Runs `stop` and then `start`. |
| `kiwi-stack status` | Lists the containers, shows the state of the host units, and runs `verify`. |
| `kiwi-stack verify` | Exits with 0 when every container is running. Otherwise it prints the containers that are not running and exits with 1. |
| `kiwi-stack logs [service]` | Follows the log of one container, or of all of them. Stop it with Ctrl+C. |
| `kiwi-stack update` | Pulls newer images and restarts the containers that got one; see [Updates](#updates). |
| `kiwi-stack vpn-restart` | Restarts the VPN client container and the containers that share its network. |
| `kiwi-stack backup`, `snapshots`, `restore MODULE...` | Run the backup module's script; see [Backups](#backups). |

The *host units* are systemd units that a module runs on the host instead of
in a container. The *mesh route* is a route on the host to the network's mesh
subnet through the VPN client container, so that the host and its containers
reach the other machines. The route is set again after every start, because
the container network is created again with the stack.

## podman and docker

The bundle decides the runtime, and the commands act on it:

| Command | podman stack | docker stack |
|---|---|---|
| `start` | `systemctl start kiwi-stack.target` | `docker compose up --detach --remove-orphans` |
| `stop` | stops `kiwi-stack.target` and every container unit | `docker compose down` |
| `status` | `podman ps` | `docker compose ps` |
| `verify` | each container's unit must be `active` | each container's state must be `running` |
| `logs` | `journalctl -f` for the container units | `docker compose logs --follow` |

On a podman stack, each container is a systemd unit made from its quadlet in
`/etc/containers/systemd/`. On a docker stack, the containers come from the
`docker-compose.yml` in the stack directory. Both stacks start at boot through
`kiwi-stack.service`, which runs `kiwi-stack start`.

## Updates

`kiwi-stack update` depends on the stack's `auto_update` setting, which
`/etc/kiwi-server/stack.env` keeps as `STACK_AUTO_UPDATE`:

- With `registry` (the default), a podman stack runs `podman auto-update`,
  which pulls a newer image for each container marked for updates and
  restarts it. A docker stack runs `docker compose pull` and then
  `docker compose up`. Unused images are removed afterwards.
- With any other value, the images change only with an apply. On a podman
  stack, `update` then says so and pulls nothing. On a docker stack, it runs
  `docker compose up` without pulling and removes unused images.

In both cases it then sets the mesh route and restarts the host units. When
the machine file sets a weekly update time, the apply installs
`kiwi-stack-update.timer`, which runs `kiwi-stack update` at that time.

## The VPN client

On a stack with a VPN client, `kiwi-stack vpn-restart` restarts the VPN
client container and every container that shares its *network namespace*
(its network interfaces and addresses). They have to restart together,
because a container left behind would sit in a namespace that no longer
exists. When the machine file sets a daily restart time, the apply installs
`kiwi-stack-vpn-restart.timer`, which runs this command every day at that
time. A restarted VPN client usually gets a new exit address.

On a stack without a VPN client, the command does nothing.

## Backups

`kiwi-stack backup`, `kiwi-stack snapshots` and `kiwi-stack restore MODULE...`
pass the command and its arguments on to `kiwi/backup.sh` in the stack
directory. The backup module of
[kiwi-modules](https://kiwi-network.eu/docs/server/modules/) puts that script
there; its documentation describes the options. On a machine without the
backup module, these commands say so and exit with 1.
