#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# help.sh
#
# Loads help text from docs/help/*.txt and prints it.
# Each command/subcommand should have a corresponding help file so users can
# run `cortex ... --help` at any level.
# -----------------------------------------------------------------------------


help_show() {
	local key="${1:-cortex}"
  local file="$DIR/docs/help/${key}.txt"

  if [[ -f "$file" ]]; then
    cat "$file"
    return 0
  fi

  cortex_err "missing help file: $file"
  cortex_err "expected help key: $key"
  return 2
}

help_key() {
	local key="${*:-cortex}"
  key="${key// /-}"
  echo "$key"
}

help_if_flag() {
  local key="$1"; shift
  for a in "$@"; do
    case "$a" in
			""|-h|--help|help)
				help_show "$key"
				return 0
				;; 
		esac
  done
  return 1
}
