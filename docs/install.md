# Install

This page says which systems kiwi-stack runs on, what it needs, and how to
install, update and remove the command. Installing changes nothing else on
the machine. The stack itself arrives when you [apply a bundle](apply.md).

## Supported systems

kiwi-stack tells the systems apart by two files. A system with
`/run/ostree-booted` is an *ostree* system, an image-based system such as
Fedora CoreOS or uCore. A system with `/etc/debian_version` is treated as
Debian, which includes Ubuntu and Armbian.

| System | What kiwi-stack does there |
|---|---|
| Fedora CoreOS, uCore | It installs no packages, because the image brings them. Every Fedora CoreOS and uCore image ships podman. For a docker stack, use a uCore image: ucore-minimal and the larger uCore images ship docker. |
| Debian, Ubuntu, Armbian | It installs the runtime with apt. For podman, that is podman, netavark, aardvark-dns, catatonit, nftables and curl. For docker, it is Docker CE from `download.docker.com` (the Ubuntu repository on Ubuntu and Ubuntu-based Armbian), or the distribution's `docker.io` package when the machine file sets `docker_source: distro`. |
| Any other Linux with systemd | The runtime must already be installed. kiwi-stack installs no packages there and stops with an error if the runtime is missing. |

A podman stack needs podman 4.4 or newer, because older versions have no
*quadlets* (systemd unit files that describe a container). On Debian this
means Debian 13 (trixie) or newer; on an older release, use `runtime: docker`
in the machine file.

What has been tested:

- **CI** runs on Ubuntu and checks the scripts: shellcheck, the command's
  argument handling, the library's pure functions and the installer (see
  [Development](development.md)). It does not apply a bundle.
- **Real hardware**: the
  [changelog](https://github.com/derlocke-ng/kiwi-stack/blob/main/CHANGELOG.md)
  records applies on masters and nodes, among them uCore, Debian and Armbian
  (arm64) machines.

## Requirements

- bash and systemd.
- Root. `kiwi-stack apply` refuses to run without it, and the other commands
  manage system units and root's containers.
- The container runtime that the bundle names, as in the table above.
- Internet access during an apply, for packages and container images. An
  image that the machine already has is used when its registry cannot be
  reached. On a docker machine without the compose plugin, the apply downloads
  the plugin from the latest docker/compose release on GitHub into
  `/usr/local/lib/docker/cli-plugins`.

## Install from a checkout

```bash
git clone https://github.com/derlocke-ng/kiwi-stack && cd kiwi-stack
sudo ./install.sh install
```

The installer puts two files in place:

| File | Mode | What it is |
|---|---|---|
| `/usr/local/bin/kiwi-stack` | 0755 | the command |
| `/usr/local/lib/kiwi-stack/lib.sh` | 0644 | the library that does the apply; the command looks for it here |

The variable `KIWI_PREFIX` installs under another prefix instead of
`/usr/local`. The command still looks for its library in
`/usr/local/lib/kiwi-stack/`, unless the variable `KIWI_STACK_LIB` names
another path, so another prefix is mainly useful for tests.

## Install with kiwi

kiwi-stack is also a kiwi app. Its `kiwi.manifest` declares the system scope
and uses `install.sh` as the installer, so
[kiwi-updater](https://kiwi-network.eu/docs/desktop/kiwi-updater/) installs
it with the same two files when one of your catalogs lists it:

```bash
kiwi install kiwi-stack
```

## Update

From a checkout, fetch the new release and run the installer again:

```bash
git pull && sudo ./install.sh update
```

Every apply also installs the running command and its library over the two
files in `/usr/local`. On a machine that kiwi-server manages, kiwi-server's
role script installs the copy that kiwi-server carries, so that copy decides
the version there.

## Uninstall

```bash
sudo ./install.sh uninstall
```

This removes the command and its library. The stack stays: its containers,
data, units and `/etc/kiwi-server/stack.env` are not touched. `kiwi-stack.service`
runs `/usr/local/bin/kiwi-stack`, so it fails at the next boot while the
command is missing. There is no command that removes a stack.
