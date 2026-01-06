#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# common.sh
#
# Small, reusable helper functions used throughout Cortex-CLI.
#
# Conventions used in this codebase:
#   - ROOT is the filesystem path to a Cortex instance.
#   - A node is a directory at ROOT/<NODE_ID>/ containing:
#       - README.md     (Markdown note; first H1 is the node title)
#       - metadata.yml  (small YAML with id/created/modified/type/state/access)
#       - assets/       (optional; attached files)
#
# NOTE: These helpers are intentionally small and dependency-free.
# -----------------------------------------------------------------------------


cortex_err(){ printf "cortex: %s\n" "$*" >&2; }
cortex_die(){ cortex_err "$*"; exit 1; }

cortex_atomic_write() {
  local f="$1"
  local d tmp
  d="$(dirname "$f")"
  mkdir -p "$d"
  tmp="$(mktemp "${d}/.tmp.XXXXXX")"
  cat >"$tmp"
  mv -f "$tmp" "$f"
}

cortex_is_root() {
  local root="$1"
	[[ -f  "$(cortex_schema_path "$root")" && -f "$root/README.md" && -f "$root/metadata.yml" ]]
}

cortex_require_root() {
  local root="$1"
  cortex_is_root "$root" || cortex_die "not a Cortex root: $root (missing .cortex/schema.yml)"
}

cortex_index_dir(){ echo "$1/.cortex/index"; }
cortex_schema_path(){ echo "$1/.cortex/schema.yml"; }
