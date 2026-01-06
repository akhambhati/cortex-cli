#!/usr/bin/env bash
set -euo pipefail

# Cortex-CLI installer
#
# This script performs a simple file install for:
#   - cortex executable
#   - man page
#   - bash completion
#
# It is intentionally minimal. You can also install manually (see README.md).

PREFIX="${PREFIX:-/usr/local}"
BASH_COMPLETION_DIR="${BASH_COMPLETION_DIR:-/etc/bash_completion.d}"

usage() {
  cat <<USAGE
Usage:
  sudo ./install.sh [--prefix PREFIX] [--completion-dir DIR]

Defaults:
  --prefix          /usr/local
  --completion-dir  /etc/bash_completion.d
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --completion-dir) BASH_COMPLETION_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

install -m 0755 bin/cortex "$PREFIX/bin/cortex"

if [[ -d "$PREFIX/share/man/man1" ]]; then
  install -m 0644 man/cortex.1 "$PREFIX/share/man/man1/cortex.1"
fi

if [[ -d "$BASH_COMPLETION_DIR" ]]; then
  install -m 0644 completions/cortex.bash "$BASH_COMPLETION_DIR/cortex"
fi

echo "Installed Cortex-CLI to $PREFIX/bin/cortex"
