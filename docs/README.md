# kiwi-stack documentation

kiwi-stack is the part of Kiwi Network that runs on the machine itself. It
takes a *bundle*, a directory with the container units and configuration
files of one machine, installs it, and keeps the containers running. A
*stack* is the set of containers one machine runs. The bundle comes from
kiwi-modules for a single machine or from kiwi-server for a fleet.

| Page | For | What it covers |
|---|---|---|
| [Install](install.md) | everyone | what it needs, supported systems, install, uninstall |
| [Using kiwi-stack](usage.md) | everyone | every command |
| [What apply does](apply.md) | everyone | the steps of `kiwi-stack apply`, and what happens when one fails |
| [Files and variables](reference.md) | people who look inside | what the bundle must contain and what kiwi-stack leaves on the machine |
| [Development](development.md) | contributors | checks, CI, releases |

These pages are also on [kiwi-network.eu](https://kiwi-network.eu/docs/),
where they are pulled from this folder at every release.
