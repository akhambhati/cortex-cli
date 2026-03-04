#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# schema.sh
#
# Loads and queries the instance schema at ROOT/.cortex/schema.yml.
# The schema defines mechanical constraints (node id length, required metadata
# fields, time formatting, link rules, etc.).
#
# Cortex-CLI reads the schema at runtime so most behavior can be adjusted
# per-instance without editing Bash code.
# -----------------------------------------------------------------------------

# Restricted YAML reader for schema.yml (maps + lists, no anchors).
# Compatible with mawk (no match(..., array)).

schema_get() {
  local file="$1" keypath="$2" default="${3:-}"
  awk -v kp="$keypath" -v def="$default" '
  function ltrim(s){ sub(/^[ \t]+/, "", s); return s }
  function rtrim(s){ sub(/[ \t]+$/, "", s); return s }
  function trim(s){ return rtrim(ltrim(s)) }
  BEGIN{
    found=0
    n=split(kp, want, "."); wantDepth=n;
    for(i=1;i<=40;i++) ctx[i]="";
  }
  /^[ \t]*#/ { next }
  /^[ \t]*$/ { next }
  {
    line=$0
    indent=match(line,/[^ ]/)-1
    d=int(indent/2)+1
    s=trim(line)

    if (s ~ /^- /) next

    if (s ~ /^[A-Za-z0-9_]+[ ]*:/) {
      k=s; sub(/:.*/, "", k); k=trim(k)
      v=s; sub(/^[A-Za-z0-9_]+[ ]*:[ ]*/, "", v); v=trim(v)
      gsub(/^"/, "", v); gsub(/"$/, "", v)

      ctx[d]=k
      for(i=d+1;i<=40;i++) ctx[i]=""

      ok=1
      for(i=1;i<wantDepth;i++){
        if(ctx[i]!=want[i]) { ok=0; break }
      }
      if(ok && k==want[wantDepth]) {
        found=1
        if(v=="") { print def; exit }
        print v; exit
      }
    }
  }
  END{ if(!found && def!="") print def }
  ' "$file"
}

schema_list() {
  local file="$1" keypath="$2"
  awk -v kp="$keypath" '
  function ltrim(s){ sub(/^[ \t]+/, "", s); return s }
  function rtrim(s){ sub(/[ \t]+$/, "", s); return s }
  function trim(s){ return rtrim(ltrim(s)) }
  BEGIN{
    n=split(kp, want, "."); wantDepth=n;
    inList=0; listIndent=-1;
    for(i=1;i<=40;i++) ctx[i]="";
  }
  /^[ \t]*#/ { next }
  /^[ \t]*$/ { next }
  {
    line=$0
    indent=match(line,/[^ ]/)-1
    d=int(indent/2)+1
    s=trim(line)

    if(inList){
      if(indent<=listIndent){ inList=0 }
      else if(s ~ /^- /){
        item=s; sub(/^- /, "", item); item=trim(item)
        gsub(/^"/, "", item); gsub(/"$/, "", item)
        print item
        next
      }
    }

    if (s ~ /^[A-Za-z0-9_]+[ ]*:/) {
      k=s; sub(/:.*/, "", k); k=trim(k)
      v=s; sub(/^[A-Za-z0-9_]+[ ]*:[ ]*/, "", v); v=trim(v)

      ctx[d]=k
      for(i=d+1;i<=40;i++) ctx[i]=""

      ok=1
      for(i=1;i<=wantDepth;i++){
        if(ctx[i]!=want[i]) { ok=0; break }
      }
      if(ok && v==""){
        inList=1; listIndent=indent
      }
    }
  }
  ' "$file"
}

schema_bool() {
  local file="$1" keypath="$2" default="${3:-false}"
  local v
  v="$(schema_get "$file" "$keypath" "$default" | tr '[:upper:]' '[:lower:]')"
  [[ "$v" == "true" || "$v" == "1" || "$v" == "yes" ]]
}
