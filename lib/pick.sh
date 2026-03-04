#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# pick.sh
#
# Interactive picker built from fzf + ripgrep + bat.
# The picker reads nodes.tsv to build a candidate list and uses rg for filtering
# when a query is provided.
# -----------------------------------------------------------------------------


cortex_need_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || cortex_die "missing dependency: $c"
}

cortex_pick_preview() {
	local root="${1:?root required}"
  local id="${2:-}"
  local q="${3:-}"

  local node_dir="$root/$id"
	[[ -d "$node_dir" ]] || { echo "Missing node: $id"; return 0; }
	local readme="$node_dir/README.md"
  [[ -f "$readme" ]] || { echo "Missing README.md: $readme"; return 0; }

  # Blank query: show README nicely, no highlighting
  if [[ -z "$q" ]]; then
    bat --style=plain --color=always --line-range :200 "$readme"
    return 0
  fi

  # Find first match line in README (for centering preview)
  local first_line
  first_line="$(rg -n --no-messages --max-count 1 "$q" "$readme" | awk -F: '{print $1}' || true)"
  [[ -n "$first_line" ]] || first_line=1

  # Choose a window around the first match
  local context=80
  local start end
  start=$(( first_line - context ))
  (( start < 1 )) && start=1
  end=$(( first_line + context ))

  # ----- Section 1: README preview (highlighted) -----
	# Render the window with bat, then overlay match highlighting with rg --passthru.
	# We keep color output end-to-end.
	bat --style=numbers --color=always --line-range "$start:$end" "$readme" \
		| rg --color=always --passthru --no-messages "$q" || true
}
export -f cortex_pick_preview

cortex_pick_source() {
  # Usage: cortex_pick_source ROOT QUERY INDEX_PATH
  #
  # - ROOT: cortex root directory
  # - QUERY: ripgrep pattern (can be empty)
  # - INDEX_PATH: path to nodes.tsv (usually "$ROOT/.cortex/index/nodes.tsv")
  #
  # Output: fixed-width table rows for fzf. First column is NODE_ID.

  local root="${1:?root required}"
  local query="${2:-}"
  local index="${3:?index required}"

	[[ -f "$index" ]] || return 0

  # Format TSV rows to fixed-width columns for fzf display.
  # Assumes nodes.tsv columns:
  # id, title, created, modified, type, state, access
  _cortex_pick_format() {
    awk -F'\t' '
      NR==1 { next }  # skip header
      {
				id=$1; title=$7; created=$2; modified=$3; type=$4; state=$5; access=$6

				# truncate title for display (keep it readable)
				if (length(title) > 18) title = substr(title, 1, 15) "..."

				# If created/modified are ISO with offset, you can optionally strip offset for display:
				created = substr(created,1,10) " " substr(created,12,8)
				modified = substr(modified,1,10) " " substr(modified,12,8)

				# print fixed-width columns (spaces)
				printf "%-8s  %-20s  %-21s  %-21s  %-10s %-10s %-10s\n",
							 id, title, created, modified, type, state, access
      }'
  }

  # 1) If query is empty: show everything in the index.
  if [[ -z "$query" ]]; then
    _cortex_pick_format < "$index"
    return 0
  fi

  # 2) Build TARGET_DIRS from node IDs in the index.
  #    We only include IDs that look like node dirs (directories existing under root).
  local -a TARGET_DIRS=()
  local id
  while IFS=$'\t' read -r id _rest; do
    [[ "$id" == "id" ]] && continue  # header
    [[ -n "$id" ]] || continue
    [[ -d "$root/$id" ]] || continue
    TARGET_DIRS+=("$root/$id")
  done < "$index"

  # If there are no node dirs, nothing to show.
  ((${#TARGET_DIRS[@]} > 0)) || return 0

  # 3) Run ripgrep across the target dirs. We prefer --files-with-matches so parsing is stable.
  command -v rg >/dev/null 2>&1 || return 0

  # Note: rg defaults to skipping binaries; that’s usually what you want for assets.
  # If you want to force text search across "binary-looking" files, add: --text
  local ids
  ids="$(
    rg --files-with-matches --no-messages --hidden \
       --glob '!**/.cortex/**' --glob '!**/.git/**' \
       "$query" "${TARGET_DIRS[@]}" \
    | awk -v R="$root/" '{
        p=$0
        sub("^"R, "", p)      # strip leading root/
        split(p, a, "/")
        if (a[1] != "") print a[1]   # a[1] is NODE_ID
      }' \
    | sort -u
  )"

  [[ -n "$ids" ]] || return 0

  # 4) Select and output relevant rows in the index for matching node IDs.
  #    Use awk membership set for speed.
  awk -F'\t' -v IDS="$ids" '
    BEGIN {
      n=split(IDS, a, "\n");
      for (i=1; i<=n; i++) if (a[i] != "") ok[a[i]]=1;
    }
    NR==1 { next }
    ok[$1] {
				id=$1; title=$7; created=$2; modified=$3; type=$4; state=$5; access=$6

				# truncate title for display (keep it readable)
				if (length(title) > 18) title = substr(title, 1, 15) "..."

				# If created/modified are ISO with offset, you can optionally strip offset for display:
				created = substr(created,1,10) " " substr(created,12,8)
				modified = substr(modified,1,10) " " substr(modified,12,8)

				# print fixed-width columns (spaces)
				printf "%-8s  %-20s  %-21s  %-21s  %-10s %-10s %-10s\n",
							 id, title, created, modified, type, state, access
      }
		' "$index" 
}
export -f cortex_pick_source

cortex_pick() {
  local root="$1"; shift
  cortex_require_root "$root"
  index_ensure_fresh "$root" || true

  cortex_need_cmd fzf
	cortex_need_cmd rg
	cortex_need_cmd bat
  local f="$(cortex_index_dir "$root")/nodes.tsv"

	INITIAL_QUERY="${*:-}"
	NODES="$root"/*/
	sel="$(fzf \
		--phony \
		--query "$INITIAL_QUERY" \
		--bind "start:reload:cortex_pick_source $root {q} $f" \
		--bind "change:reload:cortex_pick_source $root {q} $f" \
		--prompt="cortex> " \
		--header="$(printf "%-8s  %-20s  %-21s  %-21s  %-10s %-10s %-10s\n" id title created modified type state access)" \
		--preview "cortex_pick_preview $root {1} {q}" \
		--preview-window "up,40%,border-bottom")"
	echo "$sel"	
}
