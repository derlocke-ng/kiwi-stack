# kiwi-stack

kiwi-stack runs on the machine that runs your services. It takes a bundle (a
directory with the container units and configuration files of one machine),
installs it, starts the containers and keeps them running. The bundle comes
from [kiwi-modules](https://github.com/derlocke-ng/kiwi-modules) for a single
machine, or from [kiwi-server](https://github.com/derlocke-ng/kiwi-server)
for a fleet.

It is part of the network side of Kiwi Network. A machine that kiwi-server
installs gets kiwi-stack by itself. Install it by hand on a machine you set
up yourself.

- Runs on: Fedora CoreOS, uCore, Debian and Armbian; see
  [Install](docs/install.md) for what was tested where
- Needs: bash, systemd, and podman 4.4 or newer or docker with the compose plugin
- License: GPL-3.0-or-later

## Install

```bash
git clone https://github.com/derlocke-ng/kiwi-stack
cd kiwi-stack
sudo ./install.sh install
```

The installer puts the command at `/usr/local/bin/kiwi-stack` and its library
at `/usr/local/lib/kiwi-stack/lib.sh`. It needs root.

## Quick start

```bash
sudo kiwi-stack apply /tmp/sh3.bundle
sudo kiwi-stack status
```

`apply` installs the bundle and starts its containers. `status` shows them
and names any that is not running.

## Documentation

| Page | What it covers |
|---|---|
| [Install](docs/install.md) | what it needs, supported systems, install, uninstall |
| [Using kiwi-stack](docs/usage.md) | every command |
| [What apply does](docs/apply.md) | the steps of an apply, and what happens when one fails |
| [Files and variables](docs/reference.md) | what a bundle contains and what stays on the machine |
| [Development](docs/development.md) | checks, CI, releases |

The same pages are on [kiwi-network.eu](https://kiwi-network.eu/docs/server/single/).

## License

GPL-3.0-or-later; see [LICENSE](LICENSE).
