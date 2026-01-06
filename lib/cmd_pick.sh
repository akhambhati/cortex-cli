#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# cmd_pick.shpick.sh
#
# Command dispatcher for the cortex CLI.
# Parses arguments for a top-level command and delegates to library functions.
# -----------------------------------------------------------------------------

cmd_pick() {
    sub="${1:-}"; shift || true
    cortex_require_root "$ROOT"

		case "$sub" in
			""|-h|--help|help)
				help_show "pick"
				return 0
				;;
		esac

    case "$sub" in
      edit)
        help_if_flag "pick-edit" "$@" && return 0
				sel="$(cortex_pick "$ROOT" "$@")"
        [[ -n "$sel" ]] || return 0
				cmd_node edit "$(awk '{print $1}' <<< "$sel")"
				clear
        ;;
      rm)
        help_if_flag "pick-rm" "$@" && return 0
				sel="$(cortex_pick "$ROOT" "$@")"
        [[ -n "$sel" ]] || return 0
				cmd_node rm "$(awk '{print $1}' <<< "$sel")"
        ;;
      link)
        help_if_flag "pick-link" "$@" && return 0
				sel="$(cortex_pick "$ROOT" "$@")"
        [[ -n "$sel" ]] || return 0
				id="$(awk '{print $1}' <<< "$sel")"
				title="$(awk '{print $2}' <<< "$sel")"
				printf  '[%s](%s/README.md)' "$title" "$id"
        ;;
      *) cortex_die "unknown pick subcommand: $sub";;
    esac
}
