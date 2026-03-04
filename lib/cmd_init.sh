#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# cmd_init.shinit.sh
#
# Command dispatcher for the cortex CLI.
# Parses arguments for a top-level command and delegates to library functions.
# -----------------------------------------------------------------------------

cmd_init() {
	target="${1:-}"; shift || true

	case "$target" in
		""|-h|--help|help)
			help_show "init"
			return 0
			;;
	esac

  [[ -n "$target" ]] || cortex_die "init: ROOT required"
	title=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--title) title="$2"; shift 2;;
			*) cortex_die "init: unknown arg: $1";;
		esac
	done
	[[ -n "$title" ]] || cortex_die "init: --title required"
	mkdir -p "$target/.cortex/index" "$target/.cortex/locks"
	[[ -f "$SCHEMA_PATH" ]] || cortex_die "missing schema template: $SCHEMA_PATH"
	install -m 0644 "$SCHEMA_PATH" "$target/.cortex/schema.yml" 2>/dev/null \
		|| cp -f "$SCHEMA_PATH" "$target/.cortex/schema.yml"

  readme_write_new "$target" "$target/README.md" "$title"
	meta_write_minimal "$target" "$target/metadata.yml" "ROOT" "cortex" "active" "private"

  index_build_all "$target" >/dev/null || true
	echo "$target"
}
