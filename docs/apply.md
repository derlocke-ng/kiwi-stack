# Apply a bundle

`kiwi-stack apply DIR` puts the stack described by a bundle onto this machine
and starts it. This page says what a bundle is, what an apply does step by
step, what happens when you apply again, and what to do when an apply fails.

## The bundle

A bundle is a directory that
[kiwi-modules](https://kiwi-network.eu/docs/server/modules/) writes with
`kiwi-modules render machine.yaml -o DIR`. kiwi-server writes the same kind
of directory for each machine of a fleet. It holds:

- `stack.sh`, a bash file with the `KS_*` variables that describe the stack;
- the rendered files of the stack (configuration, environment files,
  `docker-compose.yml`);
- `host-units/`, systemd units that run on the host instead of in a container;
- `quadlets/`, the podman quadlets of the containers;
- `kiwi/ca/kiwiCA.crt`, the network's CA certificate, when there is one.

[Bundle and machine contracts](contracts.md) lists every variable and file.
Copy the whole directory to the machine, for example with `scp -r`, and apply
it there as root:

```bash
sudo kiwi-stack apply /tmp/sh3.bundle
```

## What an apply does

The apply writes everything it prints to `/var/log/kiwi-server-role.log`.
It works through these steps:

1. It checks that it runs as root and that the directory holds a `stack.sh`.
2. It trusts the network's CA certificate on the host, when the bundle has
   one.
3. It creates the stack's service user, with user ID 1000 if that ID is free.
4. It makes sure the container runtime is there. With podman, it installs it
   on Debian, checks for version 4.4 or newer, and enables `podman.socket`,
   the API socket that Portainer talks to. With docker, it installs it on
   Debian, enables it, installs the compose plugin if it is missing, and adds
   the service user and the admin user to the `docker` group.
5. It prepares the host. It loads the kernel modules the stack needs and
   writes them to `/etc/modules-load.d/`, and it writes the stack's sysctls to
   `/etc/sysctl.d/90-kiwi-stack.conf`. When a podman stack runs a DNS server,
   it moves podman's own resolver from port 53 to port 5533, so that the
   stack's Pi-hole can use port 53. Where systemd-resolved runs, it points
   resolved at the stack's Pi-hole, with Quad9 as the fallback while the stack
   is down, and it turns off resolved's stub listener on port 53 when the
   stack asks for that.
6. It writes the network's names into a marked block in `/etc/hosts`, so the
   host resolves every node and service without a Pi-hole.
7. It points podman at the registry mirrors of a cache on the local network,
   and apt at its package proxy, when the machine file names them. Both fall
   back to the Internet when the cache does not answer. Without these settings
   it removes them again.
8. It unpacks the bundle into the stack directory, which is described in
   [Unpacking the bundle](#unpacking-the-bundle).
9. It installs the running `kiwi-stack` command and its library to
   `/usr/local`.
10. On a podman stack that routes the network's *mesh* (the private WireGuard
    network of the fleet) through a container, it makes the host track bridged
    container traffic (`br_netfilter`, written to
    `/etc/sysctl.d/91-kiwi-mesh.conf`). Where firewalld runs, it adds the mesh
    subnet to the trusted zone.
11. On a stack with a VPN client, it makes the boot wait for the clock to be
    set, at most 90 seconds, before the stack starts. WireGuard ignores a
    handshake older than the newest one it has seen, so a tunnel opened with a
    wrong clock would be shut out. Where chronyd runs, it uses
    `chrony-wait.service`, otherwise `systemd-time-wait-sync.service`.
12. It opens the stack's ports in firewalld or ufw, whichever is active. With
    neither, it opens nothing.
13. It pulls every image, one after the other, with three tries each. If an
    image cannot be pulled but the machine already has it, the apply warns and
    goes on.
14. It installs `kiwi-stack.service`, which starts the stack at boot, and the
    timers the stack asks for: a daily VPN client restart and a weekly update.
15. It starts the stack, as described in [Applying again](#applying-again).
16. It runs `kiwi-stack verify`. Every container must be running, or the
    apply fails and names the ones that are not. The check asks again for
    about a minute, because containers that share another container's network
    follow it a few seconds later.
17. It enables and starts the host units, and prints the stack's addresses.

At the end it writes the time of the apply to
`/var/lib/kiwi-server/stack.applied`.

The apply does not set the hostname or the time zone. A kiwi-server role
script does that before it applies the stack.

## Unpacking the bundle

Step 8 does the following, in this order:

1. If the machine has a stack already, it compares the fleet *seed* of the
   bundle with the one applied before (`KS_SEED_ID` against `STACK_SEED_ID`
   in `/etc/kiwi-server/stack.env`). The seed is the secret from which all
   generated passwords are derived. A bundle from another seed is refused,
   because the running databases still use the old passwords. See
   [What an apply refuses](#what-an-apply-refuses).
2. If the runtime or the stack directory changed, it stops the old stack
   first, so that the two do not fight for the same ports.
3. On a podman stack, it switches off a docker daemon that runs no
   containers. Docker sets iptables' `FORWARD` policy to `DROP` when it
   starts, which would cut the stack's published ports off from the network.
   If docker does run containers, it only warns.
4. On a podman stack, it stops and removes the containers that are no longer
   in the stack.
5. It creates the stack directory (owned by root, mode 0755) and the data
   directories. A new data directory belongs to the service user. An existing
   data directory keeps its owner, unless root owns it; then it goes to the
   service user. A directory with rendered files in it belongs to root and is
   writable only by root. An absolute directory that exists already, such as
   a mounted data disk, is left as it is.
6. It writes every rendered file with the mode the bundle gives it, owned by
   root.
7. It removes the rendered files and host units that the previous apply
   installed and this bundle no longer has. Data that a container wrote is
   never removed.
8. It installs the host units to `/etc/systemd/system/`.
9. On a podman stack, it removes every quadlet a previous apply wrote (they
   contain the line `# kiwi-server stack`) and installs the bundle's quadlets
   to `/etc/containers/systemd/` with mode 0600. The `.target` quadlet goes to
   `/etc/systemd/system/`. When a `.network` quadlet changed, it stops the
   stack and removes the podman network, so that the start creates it again.
10. It writes `/etc/kiwi-server/stack.env`, which the `kiwi-stack` command
    reads afterwards.

## Applying again

You can apply a bundle again at any time, the same one or a new render. Files
that did not change are written again with the same content.

- **A running podman stack** keeps running. The apply starts the containers
  that are new and restarts only those whose quadlet changed, or a file they
  mount or read (`Volume=`, `EnvironmentFile=`). A container that shares
  another container's network follows it.
- **The first apply, a stopped stack, a docker stack, or a recreated
  network**: the apply restarts `kiwi-stack.service`, which stops and starts
  the whole stack.

The host units are restarted at every apply. There is no rollback: to get an
older configuration back, apply an older bundle. To get data back, use
`kiwi-stack restore` from the [backup module](commands.md#backups).

## When an apply fails

A failed step stops the apply. kiwi-stack then writes
`/var/lib/kiwi-server/role.failed` with the step, the function, the command,
its exit code and the last 20 lines of the log. On the terminal it prints
where it stopped. The full output is in `/var/log/kiwi-server-role.log`.

Fix the cause and apply again. The next successful apply removes
`role.failed`. To see why a container did not start, use
`sudo kiwi-stack logs <name>`.

## What an apply refuses

- **Running without root.** The apply stops with "this must run as root".
- **A directory without `stack.sh`.** The apply stops and says that the
  directory is not a stack bundle.
- **A bundle from another seed.** Restore `secrets/seed` from the fleet
  backup and render again. To start over with new secrets on an empty stack,
  remove `/etc/kiwi-server/stack.env` and the data directories first.
- **podman older than 4.4**, and a missing runtime on a system where
  kiwi-stack cannot install it (see [Install](install.md#supported-systems)).
- **An image that cannot be pulled** when the machine has no copy of it.
