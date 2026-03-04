#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# cmd_validate.shvalidate.sh
#
# Command dispatcher for the cortex CLI.
# Parses arguments for a top-level command and delegates to library functions.
# -----------------------------------------------------------------------------

validate_metadata_against_schema() {
  local root="$1" f="$2"
  local schema; schema="$(cortex_schema_path "$root")"
  local key
  for key in type state access; do
    mapfile -t allowed < <(schema_list "$schema" "metadata.allowed.${key}" || true)
    if [[ "${#allowed[@]}" -gt 0 ]]; then
      validate_metadata_allowed "$f" "$key" "${allowed[@]}" || return 1
    fi
  done
  return 0
}

cmd_validate() {
  cortex_require_root "$ROOT"

  local schema mode errs
  schema="$(cortex_schema_path "$ROOT")"
  mode="$(schema_get "$schema" validate.mode "strict" | tr '[:upper:]' '[:lower:]')"
  [[ "$mode" == "off" ]] && exit 0
  errs=0

  # README + metadata checks
  if schema_bool "$schema" readme.require_h1 true; then
    if ! require_h1_first_nonempty "$ROOT/README.md"; then cortex_err "root README.md missing H1"; errs=1; fi
  fi

  mapfile -t req < <(schema_list "$schema" metadata.required_fields)
  if ! validate_metadata_required "$ROOT/metadata.yml" "${req[@]}"; then errs=1; fi
  if ! validate_metadata_against_schema "$ROOT" "$ROOT/metadata.yml"; then errs=1; fi

  # Link policy checks (schema-driven)
  links_assert_supported "$ROOT"
  local resolve ere ignore
  resolve="$(links_resolve "$ROOT")"
  ere="$(schema_node_ere "$ROOT")"
  ignore="$(schema_get "$schema" links.ignore_code_blocks "true" | tr '[:upper:]' '[:lower:]')"

  check_links_in_file() {
    local label="$1" file="$2"
    [[ -f "$file" ]] || return 0
 
    local content
    if [[ "$ignore" == "true" ]]; then
      content="$(awk 'BEGIN{blk=0} /^```/{blk=!blk; next} { if(!blk) print }' "$file")"
    else
      content="$(cat "$file")"
    fi

    local missing=0 dst
    while IFS= read -r dst; do
			[[ -n "$dst" ]] || continue
      if [[ ! -d "$ROOT/$dst" ]]; then
        case "$resolve" in
          ignore) : ;;
          warn) cortex_err "warn: ${label} links to missing node: ${dst}" ;;
          strict) cortex_err "${label} links to missing node: ${dst}"; missing=1 ;;
        esac
      fi
    done < <(echo "$content"       | grep -oE '\(([[:alnum:]]+)/README\.md\)'       | sed -E 's/^\(([[:alnum:]]+)\/README\.md\)$/\1/'       | grep -E "$ere" || true)

    return "$missing"
  }

  # Check links in root README (optional but symmetric)
  if ! check_links_in_file "ROOT" "$ROOT/README.md"; then errs=1; fi

  while IFS= read -r id; do
    if schema_bool "$schema" readme.require_h1 true; then
      if ! require_h1_first_nonempty "$ROOT/$id/README.md"; then cortex_err "$id README.md missing H1"; errs=1; fi
    fi
    if ! validate_metadata_required "$ROOT/$id/metadata.yml" "${req[@]}"; then errs=1; fi
      if ! validate_metadata_against_schema "$ROOT" "$ROOT/$id/metadata.yml"; then errs=1; fi

    if ! check_links_in_file "$id" "$ROOT/$id/README.md"; then errs=1; fi
  done < <(node_list_fs "$ROOT")

  [[ "$errs" -eq 0 ]] || exit 1
}
