#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# links.sh
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
# This file contains functions related to: links.sh.
# -----------------------------------------------------------------------------

# Enforce link-related schema knobs
links_syntax() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" links.syntax "paren_path" | tr '[:upper:]' '[:lower:]'
}

links_resolve() {
  local root="$1"
  local schema; schema="$(cortex_schema_path "$root")"
  schema_get "$schema" links.resolve "strict" | tr '[:upper:]' '[:lower:]'
}

links_assert_supported() {
  local root="$1"
  local syntax resolve
  syntax="$(links_syntax "$root")"
  resolve="$(links_resolve "$root")"

  case "$syntax" in
    paren_path) : ;;
    *) cortex_die "links.syntax=$syntax not supported (supports: paren_path)" ;;
  esac

  case "$resolve" in
    strict|warn|ignore) : ;;
    *) cortex_die "links.resolve=$resolve not supported (use strict|warn|ignore)" ;;
  esac
}
