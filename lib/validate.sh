#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# validate.sh
#
# Validates that a Cortex instance matches its schema (read-only).
# Reports errors but does not mutate the instance.
# -----------------------------------------------------------------------------


require_h1_first_nonempty() {
  local f="$1"
  local line
  line="$(grep -m1 -v '^[[:space:]]*$' "$f" 2>/dev/null || true)"
  [[ "$line" =~ ^#[[:space:]]+.+$ ]]
}

extract_title() {
  local f="$1"
  local line
  line="$(grep -m1 -E '^#[[:space:]]+' "$f" 2>/dev/null || true)"
  line="${line#\# }"
  echo "$line"
}

meta_has_key() {
  local f="$1" key="$2"
  grep -q -E "^${key}:[[:space:]]*" "$f"
}

meta_get_value() {
  local f="$1" key="$2"
  grep -E "^${key}:[[:space:]]*" "$f" | head -n1 | sed -E "s/^${key}:[[:space:]]*//"
}

validate_metadata_allowed() {
  local f="$1" key="$2"; shift 2
  local val; val="$(meta_get_value "$f" "$key")"
  [[ -z "$val" ]] && return 0  # required check elsewhere
  local allowed
  for allowed in "$@"; do
    [[ "$val" == "$allowed" ]] && return 0
  done
  echo "invalid value for '$key' in $f: '$val' (allowed: $*)"
  return 1
}

validate_metadata_required() {
  local f="$1"; shift
  local fail=0
  for k in "$@"; do
    if ! meta_has_key "$f" "$k"; then
      echo "missing metadata key '$k' in $f"
      fail=1
    fi
  done
  return $fail
}
