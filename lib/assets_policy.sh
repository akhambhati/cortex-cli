#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# assets_policy.sh
#
# Cortex-CLI is a small Bash-based CLI that manages a directory of Markdown
# notes ("nodes") plus minimal YAML metadata.
#
# Key concepts:
#   - Cortex root: a folder containing .cortex/ plus node directories.
#   - Node: ROOT/<NODE_ID>/ with README.md + metadata.yml (+ optional assets/).
#   - Schema: ROOT/.cortex/schema.yml configures constraints (id length,
#     required metadata fields, validation behavior, etc.).
#
# This file contains functions related to: assets_policy.sh.
# -----------------------------------------------------------------------------

assets_assert_supported() {
  local root="$1"
  local schema mode coll ov
  schema="$(cortex_schema_path "$root")"

  mode="$(schema_get "$schema" assets.store_mode "node" | tr '[:upper:]' '[:lower:]')"
  [[ "$mode" == "node" ]] || cortex_die "assets.store_mode=$mode not supported (Cortex-CLI supports: node)"

  coll="$(schema_get "$schema" assets.collision "reject" | tr '[:upper:]' '[:lower:]')"
  case "$coll" in reject|rename|overwrite) ;; *) cortex_die "assets.collision=$coll not supported (use reject|rename|overwrite)" ;; esac

  ov="$(schema_get "$schema" assets.on_oversize "warn" | tr '[:upper:]' '[:lower:]')"
  case "$ov" in warn|reject|allow) ;; *) cortex_die "assets.on_oversize=$ov not supported (use warn|reject|allow)" ;; esac
}

assets_dir_rel() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" assets.dir "assets"
}

assets_dir_abs() {
  local root="$1" id="$2"
  local rel; rel="$(assets_dir_rel "$root")"
  echo "$root/$id/$rel"
}

assets_max_inline_bytes() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" assets.max_inline_bytes "50000000"
}

assets_on_oversize() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" assets.on_oversize "warn" | tr '[:upper:]' '[:lower:]'
}

assets_collision() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" assets.collision "reject" | tr '[:upper:]' '[:lower:]'
}

assets_keep_original_name() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" assets.keep_original_name "true" | tr '[:upper:]' '[:lower:]'
}

assets_ext_allowed() {
  # returns 0 if allowed, 1 if disallowed
  local root="$1" path="$2"
  local schema ext
  schema="$(cortex_schema_path "$root")"

  mapfile -t exts < <(schema_list "$schema" assets.allowed_ext)
  # If no allowlist specified (or empty list), allow everything
  if [[ "${#exts[@]}" -eq 0 ]]; then
    return 0
  fi

  ext="${path##*/}"
  ext="${ext##*.}"
  ext="$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"
  [[ "$ext" != "$path" ]] || return 0

  local e
  for e in "${exts[@]}"; do
    [[ -n "$e" ]] || continue
    e="$(printf "%s" "$e" | tr '[:upper:]' '[:lower:]')"
    if [[ "$ext" == "$e" ]]; then return 0; fi
  done
  return 1
}

assets_choose_dest_name() {
  # Usage: assets_choose_dest_name ROOT SRC_BASENAME
  # Honors keep_original_name (if false, generate a timestamped name but keep extension).
  local root="$1" base="$2"
  local keep; keep="$(assets_keep_original_name "$root")"
  if [[ "$keep" == "true" ]]; then
    printf "%s
" "$base"
    return 0
  fi

  local ext=""
  if [[ "$base" == *.* ]]; then
    ext=".${base##*.}"
  fi
  # compact timestamp safe for filenames
  local ts; ts="$(cortex_time_now "$root" | tr -d ':' | tr -d '-' | tr -d 'T' | tr -d '+' | tr -d 'Z' | tr -d '.')"
  printf "asset_%s%s
" "$ts" "$ext"
}
