#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# cmd_asset.shasset.sh
#
# Command dispatcher for the cortex CLI.
# Parses arguments for a top-level command and delegates to library functions.
# -----------------------------------------------------------------------------

cmd_asset() {
    sub="${1:-}"; shift || true
    cortex_require_root "$ROOT"

		case "$sub" in
			""|-h|--help|help)
				help_show "asset"
				return 0
				;;
		esac
   
		case "$sub" in
      list)
			  help_if_flag "asset-list" "$@" && return 0
        id="${1:-}"; [[ -n "$id" ]] || cortex_die "asset list: ID required"
        asset_list "$ROOT" "$id"
        ;;
      attach)
 			  help_if_flag "asset-attach" "$@" && return 0
        id="${1:-}"; shift || true
        [[ -n "$id" ]] || cortex_die "asset attach: ID required"
        [[ $# -gt 0 ]] || cortex_die "asset attach: files required"
        asset_attach "$ROOT" "$id" "$@"
        ;;
      rm)
 			  help_if_flag "asset-rm" "$@" && return 0
        id="${1:-}"; shift || true
        name="${1:-}"; shift || true
        [[ -n "$id" && -n "$name" ]] || cortex_die "asset rm: usage: cortex asset rm ID FILENAME"
        asset_rm "$ROOT" "$id" "$name"
        ;;
      *) cortex_die "unknown asset subcommand: $sub";;
    esac
}
