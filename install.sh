#!/usr/bin/env bash
# kiwi-stack installer: the CLI to /usr/local/bin, its library to
# /usr/local/lib/kiwi-stack/lib.sh (where the CLI looks, and where a kiwi-server
# role script puts the same two files).
#   sudo ./install.sh install|update|uninstall [--purge]   (a kiwi-updater installer: system scope, /usr/local)
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX=${KIWI_PREFIX:-/usr/local}

case ${1:-} in
    install|update)
        install -Dm755 "$SRC/kiwi-stack" "$PREFIX/bin/kiwi-stack"
        install -Dm644 "$SRC/lib.sh" "$PREFIX/lib/kiwi-stack/lib.sh"
        echo ":: installed $PREFIX/bin/kiwi-stack — sudo kiwi-stack apply DIR"
        ;;
    uninstall)
        rm -f "$PREFIX/bin/kiwi-stack"
        rm -rf "$PREFIX/lib/kiwi-stack"
        echo ":: removed kiwi-stack (the stack on this machine, /etc/kiwi-server/stack.env and the units, stays)"
        ;;
    *) echo "usage: $0 install|update|uninstall" >&2; exit 1 ;;
esac
