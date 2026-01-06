#!/usr/bin/env bash
set -euo pipefail


# -----------------------------------------------------------------------------
# BEGIN CORTEX-CLI DOC
#
# asset.sh
#
# Asset primitives. Assets are regular files stored alongside a node, typically
# under <NODE_ID>/assets/. Cortex-CLI can attach/list/remove assets and update
# the assets index.
# -----------------------------------------------------------------------------


asset_list() {
  local root="$1" id="$2"
  assets_assert_supported "$root"
  index_ensure_fresh "$root" || true

  local rel adir f
  rel="$(assets_dir_rel "$root")"
  adir="$(assets_dir_abs "$root" "$id")"

  # Prefer index if present
  f="$(cortex_index_dir "$root")/assets.tsv"
  if [[ -f "$f" ]]; then
    awk -v id="$id" 'NR==1{next} $1==id{print $2}' "$f"
    return 0
  fi

  find "$adir" -maxdepth 1 -type f -printf "${rel}/%f
" 2>/dev/null | sort || true
}

asset_attach() {
  local root="$1" id="$2"; shift 2
  assets_assert_supported "$root"

  local adir; adir="$(assets_dir_abs "$root" "$id")"
  [[ -d "$adir" ]] || cortex_die "node not found: $id"

  local maxb on_over coll
  maxb="$(assets_max_inline_bytes "$root")"
  on_over="$(assets_on_oversize "$root")"
  coll="$(assets_collision "$root")"

	prehash="$(node_fingerprint "$root/$id")"
 
  for src in "$@"; do
    [[ -f "$src" ]] || cortex_die "asset attach: not a file: $src"

    if ! assets_ext_allowed "$root" "$src"; then
      cortex_die "asset attach: extension not allowed by schema: $(basename "$src")"
    fi

    local base dest sz
    base="$(basename "$src")"
    dest="$(assets_choose_dest_name "$root" "$base")"

    sz="$(wc -c <"$src" | tr -d ' ')"
    if [[ "$sz" -gt "$maxb" ]]; then
      case "$on_over" in
        reject) cortex_die "asset attach: oversize ($sz bytes) rejected by schema: $base" ;;
        warn) cortex_err "warn: oversize ($sz bytes) attached: $base" ;;
        allow) : ;;
      esac
    fi

    local dst="$adir/$dest"
    if [[ -e "$dst" ]]; then
      case "$coll" in
        reject)
          cortex_die "asset attach: target exists (collision=reject): $dest"
          ;;
        overwrite)
          : # proceed
          ;;
        rename)
          local stem ext n
          stem="${dest%.*}"
          ext=""
          [[ "$dest" == *.* ]] && ext=".${dest##*.}"
          n=1
          while [[ -e "$adir/${stem}__${n}${ext}" ]]; do n=$((n+1)); done
          dst="$adir/${stem}__${n}${ext}"
          ;;
      esac
    fi

    cp -f "$src" "$dst"
  done

	posthash="$(node_fingerprint "$root/$id")"
	if [[ "$prehash" != "$posthash" ]]; then
		node_touch "$root" "$id" >/dev/null || true
		index_after_mutation "$root" "$id" || true
	fi
}

asset_rm() {
  local root="$1" id="$2" name="$3"
  assets_assert_supported "$root"
	
	prehash="$(node_fingerprint "$root/$id")"

  local adir; adir="$(assets_dir_abs "$root" "$id")"
  local p="$adir/$name"
  [[ -f "$p" ]] || cortex_die "asset not found: $id/$name"
  rm -f "$p"

	posthash="$(node_fingerprint "$root/$id")"
	if [[ "$prehash" != "$posthash" ]]; then
		node_touch "$root" "$id" >/dev/null || true
		index_after_mutation "$root" "$id" || true
	fi
}
