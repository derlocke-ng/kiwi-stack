# kiwi-stack documentation

kiwi-stack puts a container stack onto one machine and keeps it running. A
*stack* is the set of containers and services that a machine runs. A
*bundle* is a directory with the stack's rendered configuration, which
[kiwi-modules](https://kiwi-network.eu/docs/server/modules/) or
[kiwi-server](https://kiwi-network.eu/docs/server/) writes. To *apply* a
bundle means to put it onto the machine and start the stack. kiwi-server's
role scripts carry the same code, so a machine ends up the same either way.

| Page | For | What it covers |
|---|---|---|
| [Install](install.md) | everyone | supported systems, requirements, install, update and uninstall |
| [Apply a bundle](apply.md) | everyone | what an apply does step by step, applying again, failures |
| [The kiwi-stack command](commands.md) | everyone | every command for running the stack afterwards |
| [Bundle and machine contracts](contracts.md) | module and tool authors | the variables, files and units that kiwi-stack reads and writes |
| [Development](development.md) | contributors | tests, CI, releases, the copy in kiwi-server |

These pages are also on
[kiwi-network.eu](https://kiwi-network.eu/docs/server/single/), where they are
pulled from this folder at every release.
