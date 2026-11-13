# kiwi-stack

kiwi-stack puts a container stack onto one machine and keeps it running. A
*stack* is the set of containers and services that a machine runs, and a
*bundle* is a directory with the stack's rendered configuration. kiwi-stack
takes a bundle that kiwi-modules or kiwi-server rendered and applies it to a
Fedora CoreOS, uCore or Debian machine. It installs the container runtime on
Debian, writes the files, installs the systemd units, opens the firewall
ports, starts the containers and checks that each one is running. Afterwards the
`kiwi-stack` command starts, stops, updates and inspects the stack.

kiwi-stack is the part of the Kiwi network that runs on each machine.
kiwi-server's role scripts carry the same library and install the same
command, so a machine ends up the same whether kiwi-server set it up or you
applied a bundle with kiwi-stack. Use kiwi-stack on its own when you want a
stack on one machine without a fleet.

- Latest release: **v0.7.1**
- Runs on: Fedora CoreOS, uCore, Debian and Debian-based systems such as
  Ubuntu and Armbian, as root. CI checks the scripts, not an apply on a
  machine ([supported systems](docs/install.md#supported-systems)).
- License: GPL-3.0-or-later

## Install

On the machine:

```bash
git clone https://github.com/derlocke-ng/kiwi-stack && cd kiwi-stack
sudo ./install.sh install
```

The installer copies the command to `/usr/local/bin/kiwi-stack` and its
library to `/usr/local/lib/kiwi-stack/lib.sh`. Nothing else on the machine
changes until you apply a bundle. kiwi-stack needs bash and systemd, and the
container runtime that the bundle names: podman 4.4 or newer, or docker with
the compose plugin. On Debian, the apply installs the runtime itself.

## Quick start

Render a bundle on your workstation with
[kiwi-modules](https://kiwi-network.eu/docs/server/modules/), copy it to the
machine, and apply it there:

```bash
kiwi-modules render sh3/sh3.yaml -o sh3/sh3.bundle
scp -r sh3/sh3.bundle sh3:/tmp/
ssh sh3 sudo kiwi-stack apply /tmp/sh3.bundle
ssh sh3 sudo kiwi-stack status
```

The apply ends by checking that every container is running. If one is not,
the apply fails and names it. You can apply a bundle again at any time. On a
running podman stack, an apply restarts only the containers whose
configuration changed. How to write the machine file and render it is
described on the kiwi-modules page.

## Documentation

| Page | What it covers |
|---|---|
| [Install](docs/install.md) | supported systems, requirements, install, update and uninstall |
| [Apply a bundle](docs/apply.md) | what an apply does step by step, applying again, failures |
| [The kiwi-stack command](docs/commands.md) | every command for running the stack afterwards |
| [Bundle and machine contracts](docs/contracts.md) | the variables, files and units that kiwi-stack reads and writes |
| [Development](docs/development.md) | tests, CI, releases, the copy in kiwi-server |

The same pages are on
[kiwi-network.eu](https://kiwi-network.eu/docs/server/single/), under "One
machine, without a fleet".

## Status

kiwi-stack has applied stacks to real machines. [CHANGELOG.md](CHANGELOG.md)
records what each round on hardware found, on masters and on nodes running
uCore, Debian and Armbian (arm64). Known gaps: there is no rollback, there is
no command that removes a stack, and an apply never closes a firewall port
that an earlier apply opened.

## License

GPL-3.0-or-later; see [LICENSE](LICENSE).
