# Install

kiwi-stack is a bash command with one library file. It runs on the machine
that runs your services, as root.

A machine that kiwi-server installs gets kiwi-stack by itself at its first
boot. You only install it by hand on a machine that you set up yourself, to
apply a bundle from kiwi-modules.

## What it needs

- bash and systemd.
- podman 4.4 or newer, or docker with the compose plugin. Which one is used
  is written in the bundle. `kiwi-stack apply` installs or enables it when it
  is missing.

## Supported systems

| System | Status |
|---|---|
| uCore | tested on real hardware |
| Fedora CoreOS | tested on a virtual server |
| Debian on amd64 | tested on a virtual server |
| Debian on arm64 | tested in a virtual machine |
| Armbian (Debian or Ubuntu based) | tested on an Odroid N2+ |
| Other systems | not tested yet |

The continuous integration checks the scripts without a machine: they parse,
and `shellcheck` finds nothing.

## Install from a checkout

```bash
git clone https://github.com/derlocke-ng/kiwi-stack
cd kiwi-stack
sudo ./install.sh install
```

This puts the command at `/usr/local/bin/kiwi-stack` and the library at
`/usr/local/lib/kiwi-stack/lib.sh`. `KIWI_PREFIX=/some/path` installs under
another path.

`sudo ./install.sh update` does the same and replaces the installed copy.

## Uninstall

```bash
sudo ./install.sh uninstall
```

This removes the command and the library. The stack on the machine stays:
its containers, its units and `/etc/kiwi-server/stack.env` are not touched.
