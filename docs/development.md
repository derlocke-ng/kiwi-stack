# Development

kiwi-stack is two files: the command `kiwi-stack` and the library `lib.sh`.
The library holds everything `apply` does. kiwi-server pastes the same
library into the script that sets up a machine at its first boot, so a change
here reaches every machine of a fleet.

## Run the checks

```bash
bash tests/check.sh
```

It needs `shellcheck`. It checks what can be checked without a machine: both
scripts parse, `shellcheck` finds nothing, and the command answers sensibly
when it is called without a bundle or without root.

Whether an apply works on a real system is tested with kiwi-server on real
machines. There is no test here that installs a stack.

## What CI checks

On every push and pull request, on Ubuntu: `bash tests/check.sh`.

## Release

The version is the `VERSION` line in `kiwi.manifest`, and `CHANGELOG.md` gets
an entry. When a change with a new version reaches the `main` branch, a
workflow makes the tag `vX.Y.Z` and the release. Nothing is tagged by hand.

## How kiwi-server takes a release

kiwi-server carries a copy of `kiwi-stack` and `lib.sh`. Its script
`tools/vendor.sh` copies a release in by tag, and its file `VENDORED` names
the tag. A change here reaches a fleet when kiwi-server has taken the release
and has been released itself.

## Compatibility

The variable names of the bundle and the files on the machine are listed in
[Files and variables](reference.md). Machines that were applied long ago
still carry them. Add names; do not rename or remove one without a plan for
the machines that have the old one.
