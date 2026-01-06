#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# node.sh
#
# Node primitives:
#   - create a new node directory
#   - open/edit a node
#   - update node title/metadata
#   - delete nodes
#
# Node IDs are immutable. The node title is stored in README.md as the first H1.
# -----------------------------------------------------------------------------


node_fingerprint() {
	local p="$1"
	hash="$(find "$p" -type f -exec sha256sum {} + | sha256sum)"
	echo "$hash"
}

node_id_regex() {
  local root="$1" schema; schema="$(cortex_schema_path "$root")"
  local charset len
  charset="$(schema_get "$schema" node_id.charset "A-Z0-9")"
  len="$(schema_get "$schema" node_id.length "4")"
  echo "^[${charset}]{$len}$"
}

node_id_generate() {
  local root="$1" schema; schema="$(cortex_schema_path "$root")"
  local charset len caseopt
  charset="$(schema_get "$schema" node_id.charset "A-Z0-9")"
	len="$(schema_get "$schema" node_id.length "4")"
  caseopt="$(schema_get "$schema" node_id.case "upper")"
	trset="$charset"
  local id
  while :; do
    # Avoid pipefail+SIGPIPE causing nonzero exit in command substitution
    id="$( { tr -dc "$trset" </dev/urandom | head -c "$len"; } || true )"
    [[ "$caseopt" == "lower" ]] && id="$(echo "$id" | tr '[:upper:]' '[:lower:]')"
    [[ "$caseopt" == "upper" ]] && id="$(echo "$id" | tr '[:lower:]' '[:upper:]')"
    [[ -e "$root/$id" ]] && continue
    if schema_list "$schema" node_id.reserved | grep -qx "$id"; then continue; fi
    echo "$id"; return 0
  done
}

meta_write_minimal() {
  local root="$1" out="$2" id="$3" type="$4" state="$5" access="${6:-}"
  local schema now
	schema="$(cortex_schema_path "$root")"
	now="$(cortex_time_now "$root")"
  [[ -n "$type" ]]  || type="$(schema_get "$schema" metadata.defaults.type "note")"
  [[ -n "$state" ]] || state="$(schema_get "$schema" metadata.defaults.state "inbox")"
  [[ -n "$access" ]] || access="$(schema_get "$schema" metadata.defaults.access "private")"
  cortex_atomic_write "$out" <<EOF
$(schema_list "$schema" metadata.required_fields | while read -r k; do
  case "$k" in
    id)       echo "id: $id" ;;
    created)  echo "created: $now" ;;
    modified) echo "modified: $now" ;;
    type)     echo "type: $type" ;;
    state)    echo "state: $state" ;;
    access)   echo "access: $access" ;;
    *)        echo "$k: " ;;   # future-proof: required key present but blank
  esac
done)
EOF
}

readme_write_new() {
  local root="$1" out="$2" title="$3"
  local schema require rule
  schema="$(cortex_schema_path "$root")"
  require="$(schema_get "$schema" readme.require_h1 "true" | tr '[:upper:]' '[:lower:]')"
  rule="$(schema_get "$schema" readme.h1_rule "first_nonempty_line")"

  if [[ "$require" == "true" ]]; then
    [[ "$rule" == "first_nonempty_line" ]] \
      || cortex_die "readme.h1_rule=$rule not supported"
    cortex_atomic_write "$out" <<EOF
# ${title}

EOF
  else
    cortex_atomic_write "$out" <<EOF
${title}

EOF
  fi
}


node_new() {
  local root="$1"; shift
  local title="" type="" state="" access="" id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2;;
      --type) type="$2"; shift 2;;
      --state) state="$2"; shift 2;;
      --access) access="$2"; shift 2;;
      --id) id="$2"; shift 2;;
      *) cortex_die "node new: unknown arg: $1";;
    esac
  done
  [[ -n "$title" ]] || cortex_die "node new: --title is required"

  local schema; schema="$(cortex_schema_path "$root")"
  [[ -n "$type" ]] || type="$(schema_get "$schema" metadata.defaults.type "note")"
  [[ -n "$state" ]] || state="$(schema_get "$schema" metadata.defaults.state "inbox")"
  [[ -n "$access" ]] || access="$(schema_get "$schema" metadata.defaults.access "private")"

  # allowed lists (optional)
  if [[ "$(schema_list "$schema" metadata.allowed.type | wc -l | tr -d ' ')" != "0" ]]; then
    schema_list "$schema" metadata.allowed.type | grep -qx "$type" || cortex_die "type not allowed: $type"
  fi
  if [[ "$(schema_list "$schema" metadata.allowed.state | wc -l | tr -d ' ')" != "0" ]]; then
    schema_list "$schema" metadata.allowed.state | grep -qx "$state" || cortex_die "state not allowed: $state"
  fi

  if [[ -z "$id" ]]; then
    id="$(node_id_generate "$root")"
  else
    local re; re="$(node_id_regex "$root")"
    [[ "$id" =~ $re ]] || cortex_die "invalid node id by schema: $id"
    [[ -e "$root/$id" ]] && cortex_die "node exists: $id"
  fi

  local adirrel; adirrel="$(schema_get "$schema" assets.dir "assets")"
  mkdir -p "$root/$id/$adirrel"
  readme_write_new "$root" "$root/$id/README.md" "$title"
	meta_write_minimal "$root" "$root/$id/metadata.yml" "$id" "$type" "$state" "$access"

  index_after_mutation "$root" "$id" || true

  echo "$id"
}

node_list_indexed() {
  local root="$1" fmt="${2:-id}" access="${3:-}"
  index_ensure_fresh "$root" || true
  local f="$(cortex_index_dir "$root")/nodes.tsv"

  # Optional access filter (public|private)
  local awk_filter='1'
  if [[ -n "$access" ]]; then
    awk_filter="\$6==\""${access}"\""
  fi

  case "$fmt" in
    id)
      awk -F'\t' "NR>1 && ${awk_filter} {print \$1}" "$f"
      ;;
    tsv)
      if [[ -n "$access" ]]; then
        awk -F'\t' "NR==1{print;next} ${awk_filter}{print}" "$f"
      else
        cat "$f"
      fi
      ;;
    json)
      python3 - "$f" "$access" <<'PY' 2>/dev/null || exit 1
import json,sys
f=sys.argv[1]
access=sys.argv[2] if len(sys.argv)>2 else ""
rows=[]
with open(f,'r',encoding='utf-8') as fh:
  hdr=fh.readline().rstrip('\n').split('\t')
  for line in fh:
    vals=line.rstrip('\n').split('\t')
    row={hdr[i]: vals[i] if i < len(vals) else "" for i in range(len(hdr))}
    if access and row.get("access","")!=access:
      continue
    rows.append(row)
print(json.dumps(rows, indent=2))
PY
      ;;
    fs)
      node_list_fs "$root"
      ;;
    *)
      cortex_die "node list: unknown format: $fmt"
      ;;
  esac
}

node_rm() {
  local root="$1" id="$2" force="${3:-}"
  [[ -d "$root/$id" ]] || cortex_die "node not found: $id"
  if [[ "$force" != "--force" ]]; then
    if find "$root/$id/assets" -type f -print -quit 2>/dev/null | grep -q .; then
      cortex_die "node rm: assets present; use --force"
    fi
  fi
  rm -rf "$root/$id"
  index_mark_mutation "$root" || true
  local mode; mode="$(index_mode "$root")"
  if [[ "$mode" == "incremental" ]]; then
    index_remove_node "$root" "$id" || true
  else
    index_build_all "$root" || true
  fi
}

node_touch() {
  local root="$1" id="$2"
  local meta="$root/$id/metadata.yml"
  [[ -f "$meta" ]] || cortex_die "node not found: $id"
  local now
	now="$(cortex_time_now "$root")"
  if grep -q '^modified:' "$meta"; then
    sed -i -E "s/^modified:.*/modified: ${now}/" "$meta"
  else
    echo "modified: ${now}" >>"$meta"
  fi
  index_after_mutation "$root" "$id" || true
}

node_title_get() { extract_title "$1/$2/README.md"; }

node_title_set() {
  local root="$1" id="$2" title="$3"
  local f="$root/$id/README.md"
  [[ -f "$f" ]] || cortex_die "node not found: $id"
  awk -v t="$title" 'BEGIN{done=0}
    /^#[ \t]+/ && done==0 { print "# " t; done=1; next }
    { print }
  ' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
  node_touch "$root" "$id"
}

node_edit() {
  local root="$1" id="$2" file="${3:-README.md}"
  local p="$root/$id/$file"
  [[ -f "$p" ]] || cortex_die "file not found: $p"
	prehash="$(node_fingerprint "$root/$id")"
	(
		cd "$root" || exit 1
		"${EDITOR:-vim}"  "$p"
	)
	posthash="$(node_fingerprint "$root/$id")"
	if [[ "$prehash" != "$posthash" ]]; then
		node_touch "$root" "$id" || true
	fi
}
