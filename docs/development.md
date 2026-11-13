# Development

This page is for people who change kiwi-stack: how to test a change, how a
release is made, and how kiwi-server takes it over.

## The code

| File | What it is |
|---|---|
| [`kiwi-stack`](https://github.com/derlocke-ng/kiwi-stack/blob/main/kiwi-stack) | The command. `apply` loads the library; the other commands read `stack.env`. |
| [`lib.sh`](https://github.com/derlocke-ng/kiwi-stack/blob/main/lib.sh) | The library that does the apply. kiwi-server's role scripts carry the same file. |
| [`install.sh`](https://github.com/derlocke-ng/kiwi-stack/blob/main/install.sh) | The installer, also used by kiwi. |
| [`kiwi.manifest`](https://github.com/derlocke-ng/kiwi-stack/blob/main/kiwi.manifest) | The kiwi app manifest, with the version. |
| [`tests/check.sh`](https://github.com/derlocke-ng/kiwi-stack/blob/main/tests/check.sh) | The tests. |

## Tests

```bash
bash tests/check.sh
```

The tests need bash and shellcheck, and neither root nor a network. They
check what can be checked without a machine:

- `shellcheck -S warning` and `bash -n` over every script;
- the command's argument handling: `apply` without a directory, `apply` on a
  directory that is not a bundle, and a command on a machine without a stack;
- the library's pure functions: the system detection and the paths inside a
  bundle;
- that an apply removes the rendered files of a module that left the stack and
  keeps data;
- that a running stack restarts exactly the containers whose quadlet, mounted
  file or environment file changed;
- that `install.sh` installs into and uninstalls from a prefix.

CI runs the same script on Ubuntu for every push and pull request
([`.github/workflows/ci.yml`](https://github.com/derlocke-ng/kiwi-stack/blob/main/.github/workflows/ci.yml)).
Nothing in CI applies a bundle to a machine. A change to the apply itself has
to be tried on a machine.

## Releases

A release is the tag `v<VERSION>` for the `VERSION` in `kiwi.manifest`. To
make one:

1. Raise `VERSION` in `kiwi.manifest`.
2. Add a section `## <version> — <title>` at the top of
   [CHANGELOG.md](https://github.com/derlocke-ng/kiwi-stack/blob/main/CHANGELOG.md).
3. Merge the change into `main`.

On every push to `main`, the release workflow
([`.github/workflows/release.yml`](https://github.com/derlocke-ng/kiwi-stack/blob/main/.github/workflows/release.yml))
creates the tag when it does not exist yet and publishes a GitHub release with
the changelog section as its notes. It refuses a version lower than the newest
release. kiwi installs the newest version tag, and kiwi-network.eu shows these
pages as they are at that tag.

## The copy in kiwi-server

[kiwi-server](https://kiwi-network.eu/docs/server/) carries a copy of each
kiwi-stack release, pinned to its tag in kiwi-server's `VENDORED` file and
brought in with its `tools/vendor.sh`. A fix here reaches the machines of a
fleet when kiwi-server takes over the new release.

The variables, files and units in
[Bundle and machine contracts](contracts.md) are shared with kiwi-modules and
kiwi-server. Change them only together with both.
