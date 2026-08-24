#!/bin/bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
PREFIX="/usr/local"
FORCE=0

usage() {
    cat <<'USAGE'
Usage: ./install.sh [--prefix <path>] [--force]

Install proxmoxctl and its library modules.

Options:
  --prefix <path>  Installation prefix (default: /usr/local)
  --force          Allow replacement of existing target files
  -h, --help       Show this help text

No credentials or configuration files are installed.
USAGE
}

while (( $# > 0 )); do
    case "$1" in
        --prefix)
            if (( $# < 2 )); then
                echo "--prefix requires a path." >&2
                exit 1
            fi

            PREFIX="$2"
            shift 2
            ;;

        --prefix=*)
            PREFIX="${1#--prefix=}"
            shift
            ;;

        --force)
            FORCE=1
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PREFIX" || "$PREFIX" != /* ]]; then
    echo "--prefix must be an absolute path." >&2
    exit 1
fi

SOURCE_BIN="$SCRIPT_DIR/bin/proxmoxctl"
SOURCE_LIB="$SCRIPT_DIR/lib/proxmoxctl"
TARGET_BIN="$PREFIX/bin/proxmoxctl"
TARGET_LIB="$PREFIX/lib/proxmoxctl"
MODULES=(
    backup.sh
    common.sh
    config.sh
    guest.sh
    node.sh
    node_status.py
    power.sh
    snapshot.sh
)

if [[ ! -f "$SOURCE_BIN" ]]; then
    echo "Missing launcher: $SOURCE_BIN" >&2
    exit 1
fi

for module in "${MODULES[@]}"; do
    if [[ ! -f "$SOURCE_LIB/$module" ]]; then
        echo "Missing module: $SOURCE_LIB/$module" >&2
        exit 1
    fi
done

TARGETS=("$TARGET_BIN")
for module in "${MODULES[@]}"; do
    TARGETS+=("$TARGET_LIB/$module")
done

if (( ! FORCE )); then
    for target in "${TARGETS[@]}"; do
        if [[ -e "$target" || -L "$target" ]]; then
            echo "Refusing to overwrite existing target: $target" >&2
            echo "Re-run with --force to replace existing files." >&2
            exit 1
        fi
    done
fi

install -d "$PREFIX/bin" "$TARGET_LIB"
install -m 0755 "$SOURCE_BIN" "$TARGET_BIN"

for module in "${MODULES[@]}"; do
    install -m 0644 "$SOURCE_LIB/$module" "$TARGET_LIB/$module"
done

echo "Installed proxmoxctl under $PREFIX"
