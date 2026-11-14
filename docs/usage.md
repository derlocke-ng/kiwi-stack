# Using kiwi-stack

Every command runs on the machine, as root.

| Command | What it does |
|---|---|
| `kiwi-stack apply DIR` | Installs the bundle in `DIR` and starts the stack. [What apply does](apply.md) lists the steps. |
| `kiwi-stack status` | Shows the containers and the host units, and names every container that is not running. |
| `kiwi-stack verify` | Checks that every container of the stack is running. It exits with 1 and their names when one is not. |
| `kiwi-stack start` | Starts the whole stack, then the host units. |
| `kiwi-stack stop` | Stops the host units and the stack. |
| `kiwi-stack restart` | Stops and starts the stack. |
| `kiwi-stack logs [service]` | Follows the log of one container, or of all of them. |
| `kiwi-stack update` | Fetches newer images and restarts the containers that got one. |
| `kiwi-stack vpn-restart` | Restarts the VPN client and the containers that depend on it. A daily timer runs this when the bundle asks for it. |
| `kiwi-stack backup` | Saves the machine's data now. |
| `kiwi-stack snapshots` | Lists the saved states. |
| `kiwi-stack restore` | Brings data back from a saved state. |
| `kiwi-stack address` | Says which address the machine has at home and whether it is fixed. |
| `kiwi-stack address ADDRESS/PREFIX GATEWAY [DNS...]` | Gives the machine a fixed address, where systemd-networkd runs the network (Armbian). When the new address does not work, what it had before comes back within a minute. |

A *host unit* is a systemd unit that a module needs on the host itself and
not in a container, for example the routing of a gateway.

## Updates

`kiwi-stack update` only fetches images when the bundle allows automatic
updates (`STACK_AUTO_UPDATE` is `registry`, the default). Otherwise images
change with the next apply. When the bundle asks for a weekly update, a timer
runs this command.

## Backups

`backup`, `snapshots` and `restore` exist on a machine that has the `backup`
module. On any other machine they say so and stop. kiwi-server's page
[Backups](https://kiwi-network.eu/docs/server/kiwi-server/backups/) describes
how backups are set up and restored.

## A first run by hand

```bash
sudo kiwi-stack apply /tmp/sh3.bundle
sudo kiwi-stack status
```

The bundle `/tmp/sh3.bundle` was rendered with kiwi-modules on another
computer and copied to the machine.
