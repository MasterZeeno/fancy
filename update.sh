#!/usr/bin/env bash

update_main() {
  local MAIN_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local OUT_DIR="$MAIN_DIR/output"; rm -rf "$OUT_DIR"
  
  local FUNC_SH="$MAIN_DIR/funcs.sh" BUILD_SH="$MAIN_DIR/build.sh"
  [[ -s "$FUNC_SH" && -s "$BUILD_SH" ]] && source "$FUNC_SH" || return 1
  
  local DIST_OWNER="MasterZeeno" DIST_REPO="fancy"
  local DIST_EMAIL="${DIST_OWNER,,}@outlook.com"
  local SRC_OWNER="sharkdp" SRC_REPO="pastel"
  
  get_ver() { ([[ -f "$1" ]] && cat "$1" || echo "$1") | grep -iom1 'version[ =].*' | grep -Eo '[0-9.]+'; }
  print_update_msg() {
    local msg="${1:?}" slp="${2:-1}"
    local bmsg="$DIST_OWNER/$DIST_REPO"
    [[ -z "${LATEST_VERSION:-}" ]] || bmsg+=" v$LATEST_VERSION"
    
    FANCY_ARGS=(--no-print +b)
    if [[ "${msg,,}" =~ ^updated ]]; then
      FANCY_ARGS+=(--preset=success)
    else
      FANCY_ARGS+=(--color=36)
    fi
    
    clear
    fancy_print -n +d "${msg^}" 
    fancy_print --print --no-icon +b "$bmsg"
    sleep "$slp"
  }
  
  print_update_msg "checking updates for" 2
  
  local SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
  local LATEST_VERSION=$(get_ver "$SRC_TOML") CURRENT_VERSION=0
  [[ "$1" == '-f' ]] || CURRENT_VERSION=$(get_ver "$BUILD_SH")
  if ! printf '%s\n' "$CURRENT_VERSION" "$LATEST_VERSION" | sort -V | tail -n1 | grep -xq "$CURRENT_VERSION"; then
    
    print_update_msg "updating"
    
    SRC_ZIP_URL="https://github.com/$SRC_OWNER/$SRC_REPO/archive/refs/heads/master.zip"
    SRC_ZIP_SHA=$(curl -fsSL "${SRC_ZIP_URL}" | sha256sum | awk '{print $1}')
    { echo "$SRC_TOML" \
        | awk 'NR==1{next}/^ *$/{exit}NF{gsub(/\[|\]|"/,"")gsub(/ += +/,"=");print}' \
        | sed -E \
          -e "s/^(version|description)/_\1/" \
          -e "s|^(homepage)=.*|_\1=https://github.com/$DIST_OWNER/$DIST_REPO|" \
          -e "/^license/{s|[0-9.-]||g; s|.*|_\U&|; p; s|_(.*)=(.*)/(.*)|_\1_file=\1-\2, \1-\3|}"
      printf '_%s=%s\n' \
        srcurl "$SRC_ZIP_URL" sha256 "$SRC_ZIP_SHA" maintainer "$DIST_OWNER <$DIST_EMAIL>" \
        breaks "$SRC_REPO" replaces "$SRC_REPO" build_in_src true auto_update true
    } | sed -E "/^_/!d; s|(.*)=|\Utermux_pkg\1=|;s|=(.*)|=\"\1\"|g" \
      | awk '{print length, $0}' | sort -nr | cut -d' ' -f2- > "$BUILD_SH"
    
    awk 'BEGIN{n=0}/^ *$/{n++}n>=1' "$FUNC_SH" >> "$BUILD_SH"
    [[ -s "$BUILD_SH" ]] && mkdir -p "$OUTDIR"
  fi
  
  print_update_msg "updated" 0
  export MAIN_DIR OUT_DIR LATEST_VERSION
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && update_main "${1:-}"
