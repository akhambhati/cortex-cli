#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# cmd_index.shindex.sh
#
# Command dispatcher for the cortex CLI.
# Parses arguments for a top-level command and delegates to library functions.
# -----------------------------------------------------------------------------

cmd_index() {
    sub="${1:-}"; shift || true
    cortex_require_root "$ROOT"

		case "$sub" in
			""|-h|--help|help)
				help_show "index"
				return 0
				;;
		esac
 
    case "$sub" in
      build)
			  help_if_flag "index-build" "$@" && return 0
				index_build_all "$ROOT" 
				;;
      show)
        help_if_flag "index-show" "$@" && return 0
        what="${1:-}"; shift || true
        [[ -n "$what" ]] || cortex_die "index show: nodes|links|assets"
        index_ensure_fresh "$ROOT" || true
        case "$what" in nodes|links|assets) cat "$(cortex_index_dir "$ROOT")/${what}.tsv" ;; *) cortex_die "index show: nodes|links|assets";; esac
        ;;
      *) cortex_die "unknown index subcommand: $sub";;
    esac
}
