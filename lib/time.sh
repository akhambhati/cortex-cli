#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# time.sh
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
# This file contains functions related to: time.sh.
# -----------------------------------------------------------------------------

# cortex_time_now ROOT
# Emits a timestamp string that obeys schema.yml:
#   time.format, time.timezone, time.include_offset
cortex_time_now() {
  local root="$1"
  local schema fmt tz inc
  schema="$(cortex_schema_path "$root")"

  fmt="$(schema_get "$schema" time.format "iso8601" | tr '[:upper:]' '[:lower:]')"
  tz="$(schema_get "$schema" time.timezone "local" | tr '[:upper:]' '[:lower:]')"
  inc="$(schema_get "$schema" time.include_offset "true" | tr '[:upper:]' '[:lower:]')"

  # Cortex-CLI: support only iso8601 (expand later in future versions if you want)
  [[ "$fmt" == "iso8601" ]] || cortex_die "time.format=$fmt not supported (Cortex-CLI supports iso8601)"

  local tzflag=""
  case "$tz" in
    local) tzflag="" ;;
    utc|gmt|z) tzflag="-u" ;;
    *) cortex_die "time.timezone=$tz not supported (use local|utc)" ;;
  esac

  if [[ "$inc" == "true" || "$inc" == "1" || "$inc" == "yes" ]]; then
    # Example: 2026-01-02T15:04:05-08:00
    date $tzflag +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
  else
    # Example: 2026-01-02T15:04:05
    date $tzflag +"%Y-%m-%dT%H:%M:%S"
  fi
}


# cortex_time_file_mtime ROOT PATH
# Formats PATH mtime using schema time.* constraints.
cortex_time_file_mtime() {
  local root="$1" path="$2"
  local schema fmt tz inc tzflag=""
  schema="$(cortex_schema_path "$root")"
  fmt="$(schema_get "$schema" time.format "iso8601" | tr '[:upper:]' '[:lower:]')"
  tz="$(schema_get "$schema" time.timezone "local" | tr '[:upper:]' '[:lower:]')"
  inc="$(schema_get "$schema" time.include_offset "true" | tr '[:upper:]' '[:lower:]')"

  [[ "$fmt" == "iso8601" ]] || cortex_die "time.format=$fmt not supported (Cortex-CLI supports iso8601)"

  case "$tz" in
    local) tzflag="" ;;
    utc|gmt|z) tzflag="-u" ;;
    *) cortex_die "time.timezone=$tz not supported (use local|utc)" ;;
  esac

  if [[ "$inc" == "true" || "$inc" == "1" || "$inc" == "yes" ]]; then
    date $tzflag -r "$path" +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
  else
    date $tzflag -r "$path" +"%Y-%m-%dT%H:%M:%S"
  fi
}
