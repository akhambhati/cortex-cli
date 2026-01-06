#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# index.sh
#
# Index primitives. Cortex-CLI maintains TSV indexes under ROOT/.cortex/index/.
# Indexes make commands fast (list/pick/search) without rescanning the entire
# filesystem on every invocation.
#
# TSV is used because it is easy to inspect and script with awk/cut/sort.
# -----------------------------------------------------------------------------


# --- Index policy from schema.yml (Cortex-CLI) ---
index_assert_supported() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  local enabled mode fmt
  enabled="$(schema_get "$schema" index.enabled "true" | tr '[:upper:]' '[:lower:]')"
  [[ "$enabled" == "true" ]] || cortex_die "index.enabled=false not supported (Cortex-CLI requires indexes)"
  mode="$(schema_get "$schema" index.mode "incremental" | tr '[:upper:]' '[:lower:]')"
  case "$mode" in incremental|rebuild) ;; *) cortex_die "index.mode=$mode not supported (use incremental|rebuild)" ;; esac
  fmt="$(schema_get "$schema" index.format "tsv" | tr '[:upper:]' '[:lower:]')"
  [[ "$fmt" == "tsv" ]] || cortex_die "index.format=$fmt not supported (Cortex-CLI supports tsv)"
}

index_mode() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" index.mode "incremental" | tr '[:upper:]' '[:lower:]'
}

index_require_fresh() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" index.require_fresh "true" | tr '[:upper:]' '[:lower:]'
}

# Call after any mutation that may affect nodes/links/assets indexes.
# If mode=incremental, updates only that node (if provided), else rebuilds.
index_after_mutation() {
  local root="$1" id="${2:-}"
  index_assert_supported "$root"
  index_mark_mutation "$root" || true
  local mode; mode="$(index_mode "$root")"
  if [[ "$mode" == "incremental" && -n "$id" ]]; then
    index_update_node "$root" "$id" || true
  else
    index_build_all "$root" || true
  fi
}

index_stamp_path(){ echo "$(cortex_index_dir "$1")/stamp.yml"; }

index_stamp_write() {
  local root="$1" gen="$2" mut="$3" dirty="$4"
  cortex_atomic_write "$(index_stamp_path "$root")" <<EOF
generated: ${gen}
last_mutation: ${mut}
dirty: ${dirty}
EOF
}

index_mark_mutation() {
  local root="$1"
  local now
	now="$(cortex_time_now "$root")"
  local stamp; stamp="$(index_stamp_path "$root")"
  local gen="$now"
  if [[ -f "$stamp" ]]; then
    gen="$(grep -E '^generated:' "$stamp" | head -n1 | sed -E 's/^generated:[[:space:]]*//')"
    [[ -n "$gen" ]] || gen="$now"
  fi
  index_stamp_write "$root" "$gen" "$now" "true"
}

index_is_dirty() {
  local root="$1"
  local stamp; stamp="$(index_stamp_path "$root")"
  [[ -f "$stamp" ]] || return 0
  grep -q -E '^dirty:[[:space:]]*true' "$stamp"
}

schema_node_ere() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  local charset len
  charset="$(schema_get "$schema" node_id.charset "A-Z0-9")"
  len="$(schema_get "$schema" node_id.length "4")"
  echo "^[$charset]{$len}$"
}

node_list_fs() {
  local root="$1"
  local ere; ere="$(schema_node_ere "$root")"
  local d base
  for d in "$root"/*; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    [[ "$base" == ".cortex" ]] && continue
    [[ "$base" =~ $ere ]] || continue
    local adirrel; adirrel="$(schema_get "$(cortex_schema_path "$root")" assets.dir "assets")"
    [[ -f "$d/README.md" && -f "$d/metadata.yml" && -d "$d/$adirrel" ]] || continue
    echo "$base"
  done
}



extract_links() {
  local root="$1" id="$2"
  links_assert_supported "$root"

  local ere; ere="$(schema_node_ere "$root")"
  local f="$root/$id/README.md"
  [[ -f "$f" ]] || return 0

  local ignore
  ignore="$(schema_get "$(cortex_schema_path "$root")" links.ignore_code_blocks "true" | tr '[:upper:]' '[:lower:]')"

  local content
  if [[ "$ignore" == "true" ]]; then
    content="$(awk 'BEGIN{blk=0} /^```/{blk=!blk; next} { if(!blk) print }' "$f")"
  else
    content="$(cat "$f")"
  fi

  # Cortex-CLI supported syntax: paren_path strict: (NODE_ID/README.md)
  # We extract a broad alnum token then filter by schema node-id ERE.
  echo "$content" \
    | grep -oE '\(([[:alnum:]]+)\/README\.md\)' \
    | sed -E 's/^\(([[:alnum:]]+)\/README\.md\)$/\1/' \
    | grep -E "$ere" || true
}



index_build_all() {
  local root="$1"
  index_assert_supported "$root"
  mkdir -p "$(cortex_index_dir "$root")"

  local nodesf linksf assetsf
  nodesf="$(cortex_index_dir "$root")/nodes.tsv"
  linksf="$(cortex_index_dir "$root")/links.tsv"
  assetsf="$(cortex_index_dir "$root")/assets.tsv"

  cortex_atomic_write "$nodesf" <<EOF
id	created	modified	type	state	access	title
EOF
  cortex_atomic_write "$linksf" <<EOF
src	dst	context
EOF
  cortex_atomic_write "$assetsf" <<EOF
id	asset	bytes	modified
EOF

  local id
  while IFS= read -r id; do
    index_update_node "$root" "$id" --no-stamp
  done < <(node_list_fs "$root")

  local now
	now="$(cortex_time_now "$root")"
  index_stamp_write "$root" "$now" "$now" "false"
}

index_update_node() {
  local root="$1" id="$2" opt="${3:-}"
  index_assert_supported "$root"
  local idir; idir="$(cortex_index_dir "$root")"
  local nodesf="$idir/nodes.tsv"
  local linksf="$idir/links.tsv"
  local assetsf="$idir/assets.tsv"
  [[ -f "$nodesf" && -f "$linksf" && -f "$assetsf" ]] || index_build_all "$root"

  awk -v id="$id" 'NR==1{print;next} $1!=id{print}' "$nodesf" >"$nodesf.tmp" && mv "$nodesf.tmp" "$nodesf"
  awk -v id="$id" 'NR==1{print;next} $1!=id{print}' "$assetsf" >"$assetsf.tmp" && mv "$assetsf.tmp" "$assetsf"
  awk -v id="$id" 'NR==1{print;next} $1!=id{print}' "$linksf" >"$linksf.tmp" && mv "$linksf.tmp" "$linksf"

  local meta="$root/$id/metadata.yml"
  local readme="$root/$id/README.md"
  local created modified type state access title
  created="$(grep -E '^created:' "$meta" | head -n1 | sed -E 's/^created:[[:space:]]*//')"
  modified="$(grep -E '^modified:' "$meta" | head -n1 | sed -E 's/^modified:[[:space:]]*//')"
  type="$(grep -E '^type:' "$meta" | head -n1 | sed -E 's/^type:[[:space:]]*//')"
  state="$(grep -E '^state:' "$meta" | head -n1 | sed -E 's/^state:[[:space:]]*//')"
  access="$(grep -E '^access:' "$meta" | head -n1 | sed -E 's/^access:[[:space:]]*//')"
  title="$(extract_title "$readme" | tr '\t' ' ' | tr -d '\r')"

  printf "%s	%s	%s	%s	%s	%s	%s
" "$id" "$created" "$modified" "$type" "$state" "$access" "$title" >>"$nodesf"

  local a p bytes mtime
  local arel adir
  arel="$(schema_get "$(cortex_schema_path "$root")" assets.dir "assets")"
  adir="$root/$id/$arel"
  while IFS= read -r a; do
    p="$adir/$a"
    bytes="$(wc -c <"$p" | tr -d ' ')"
    mtime="$(cortex_time_file_mtime "$root" "$p")"
    printf "%s\t%s\t%s\t%s\n" "$id" "$a" "$bytes" "$mtime" >>"$assetsf"
  done < <(find "$adir" -maxdepth 1 -type f -printf "%f\n" 2>/dev/null | sort)

  local dst
  local count_dups; count_dups="$(schema_get "$(cortex_schema_path "$root")" links.count_duplicates "false" | tr '[:upper:]' '[:lower:]')"
  if [[ "$count_dups" == "true" ]]; then
    while IFS= read -r dst; do printf "%s\t%s\treadme\n" "$id" "$dst" >>"$linksf"; done < <(extract_links "$root" "$id")
  else
    while IFS= read -r dst; do printf "%s\t%s\treadme\n" "$id" "$dst" >>"$linksf"; done < <(extract_links "$root" "$id" | sort -u)
  fi

  if [[ "$opt" != "--no-stamp" ]]; then
    local now
		now="$(cortex_time_now "$root")"
    index_stamp_write "$root" "$now" "$now" "false"
  fi
}

index_remove_node() {
  local root="$1" id="$2"
  index_assert_supported "$root"
  local idir; idir="$(cortex_index_dir "$root")"
  local nodesf="$idir/nodes.tsv" linksf="$idir/links.tsv" assetsf="$idir/assets.tsv"
  [[ -f "$nodesf" && -f "$linksf" && -f "$assetsf" ]] || return 0
  awk -v id="$id" 'NR==1{print;next} $1!=id{print}' "$nodesf" >"$nodesf.tmp" && mv "$nodesf.tmp" "$nodesf"
  awk -v id="$id" 'NR==1{print;next} $1!=id{print}' "$assetsf" >"$assetsf.tmp" && mv "$assetsf.tmp" "$assetsf"
  awk -v id="$id" 'NR==1{print;next} $1!=id && $2!=id {print}' "$linksf" >"$linksf.tmp" && mv "$linksf.tmp" "$linksf"
  local now
	now="$(cortex_time_now "$root")"
  index_stamp_write "$root" "$now" "$now" "false"
}

index_ensure_fresh() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"

  # Enforce supported index knobs (Cortex-CLI)
  index_assert_supported "$root"

  local auto; auto="$(schema_get "$schema" index.auto_repair "true" | tr '[:upper:]' '[:lower:]')"
  local req; req="$(schema_get "$schema" index.require_fresh "true" | tr '[:upper:]' '[:lower:]')"

  if [[ ! -f "$(cortex_index_dir "$root")/nodes.tsv" ]]; then
    [[ "$auto" == "true" ]] || cortex_die "index missing; run: cortex index build"
    index_build_all "$root"
    return 0
  fi

  if [[ "$req" == "true" ]] && index_is_dirty "$root"; then
    [[ "$auto" == "true" ]] || cortex_die "index is stale/dirty; run: cortex index build"
    index_build_all "$root"
  fi
}
