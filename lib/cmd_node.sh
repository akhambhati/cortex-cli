#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# cmd_node.shnode.sh
#
# Command dispatcher for the cortex CLI.
# Parses arguments for a top-level command and delegates to library functions.
# -----------------------------------------------------------------------------

cmd_node() {
    sub="${1:-}"; shift || true
    cortex_require_root "$ROOT"

		case "$sub" in
			""|-h|--help|help)
				help_show "node"
				return 0
				;;
		esac

    case "$sub" in
      new)
        help_if_flag "node-new" "$@" && return 0
        node_new "$ROOT" "$@"
        ;;
      edit)
        help_if_flag "node-edit" "$@" && return 0
        id="${1:-}"; shift || true
        [[ -n "$id" ]] || cortex_die "node edit: ID required"
        file="${1:-README.md}"
        node_edit "$ROOT" "$id" "$file"
        ;;
      list)
        help_if_flag "node-list" "$@" && return 0
        fmt="id"
        access=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --format) fmt="$2"; shift 2;;
            --access) access="$2"; shift 2;;
            *) cortex_die "node list: unknown arg: $1";;
          esac
        done
        node_list_indexed "$ROOT" "$fmt" "$access"
        ;;
      rm)
        help_if_flag "node-rm" "$@" && return 0
        id="${1:-}"; shift || true
        [[ -n "$id" ]] || cortex_die "node rm: ID required"
        node_rm "$ROOT" "$id" "${1:-}"
        ;;
      touch)
        help_if_flag "node-touch" "$@" && return 0
        id="${1:-}"; shift || true
        [[ -n "$id" ]] || cortex_die "node touch: ID required"
        node_touch "$ROOT" "$id"
        ;;
      title)
        help_if_flag "node-title" "$@" && return 0
        op="${1:-}"; shift || true
        case "$op" in
          get) id="${1:-}"; [[ -n "$id" ]] || cortex_die "node title get: ID required"; node_title_get "$ROOT" "$id";;
          set) id="${1:-}"; shift || true; ttl="${1:-}"; shift || true; [[ -n "$id" && -n "$ttl" ]] || cortex_die 'node title set: usage: cortex node title set ID "New Title"'; node_title_set "$ROOT" "$id" "$ttl";;
          *) cortex_die "node title: use get|set";;
        esac
        ;;
      *) cortex_die "unknown node subcommand: $sub";;
    esac
}
