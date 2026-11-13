# What apply does

`kiwi-stack apply DIR` installs a bundle on the machine and starts its stack.
It runs as root. It reads the file `DIR/stack.sh`, which lists everything in
the bundle, and then works through the steps below.

Everything it does is written to `/var/log/kiwi-server-role.log`.

## The steps

1. **The network's CA.** When the bundle carries the certificate of the
   network's own certificate authority (`kiwi/ca/kiwiCA.crt`), the machine
   trusts it from now on.
2. **The base.** It creates the service user, installs or enables podman or
   docker, loads the kernel modules and applies the kernel settings the
   bundle names. When the stack runs its own DNS resolver, it turns off the
   local listener of systemd-resolved and points resolved at that resolver.
3. **The seed.** The *seed* is the secret from which the generated passwords
   of the stack are derived. The bundle carries a short name of its seed.
   When the machine already runs a stack from another seed, the apply stops:
   the running databases know the old passwords. The one exception is a
   bundle that names the running seed as the one it replaced. kiwi-server
   makes such bundles when it replaces a fleet's seed.
4. **The files.** When the container runtime or the stack's directory
   changed, it stops the old stack first. Then it copies the bundle into the
   stack's directory. Data directories belong to the service user, rendered
   files to root, and files with secrets get the mode `0600`. It installs the
   host units and the unit files of the containers, and removes units that an
   earlier apply installed and this bundle no longer has.
5. **Itself.** It installs the `kiwi-stack` command and its library, and
   writes `/etc/kiwi-server/stack.env`, which the command reads later.
6. **The firewall.** It opens the stack's ports in firewalld or ufw.
7. **The start.** It fetches every image, with retries. On a first apply it
   starts the whole stack. On a machine whose stack already runs, it starts
   what is new and restarts only the containers whose files changed. Then it
   starts the host units and the timers the bundle asks for: a daily restart
   of the VPN client and a weekly update.
8. **The check.** It runs `kiwi-stack verify`. Every container must be
   running. If one is not, the apply fails and names it.

## Applying again

An apply can be repeated. The same bundle a second time changes nothing. A
new render of the same machine replaces what changed and restarts only those
containers.

## When a step fails

The apply stops at the step that failed and writes
`/var/lib/kiwi-server/role.failed`. That file names the step, the command and
the last lines of the log. Fix the cause and apply again.
