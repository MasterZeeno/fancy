#!/usr/bin/env bash

get_ver() { ([[ -f "$1" ]] && cat "$1" || echo "$1") | grep -iom1 'version[ =].*' | sed 's|[^0-9.]||g'; }
print_update_msg() {
  local msg="${1:?}" slp="${2:-1}"
  local bmsg="$DIST_OWNER/$DIST_REPO"
  
  [[ -z "${LATEST_VER:-}" ]] || bmsg+=" v$LATEST_VER"
  
  FANCY_ARGS=(--no-print +b)
  if [[ "${msg,,}" =~ ^updated ]]; then
    FANCY_ARGS+=(--preset=success)
  else
    FANCY_ARGS+=(--color=36)
  fi
  
  fancy_print -n +d "${msg^}" 
  fancy_print --print --no-icon +b "$bmsg" 
}
git_push_tag() {
  local name="${1:-$DIST_OWNER}"
  local email="${2:-$DIST_EMAIL}"
  
  for v in name email; do for s in global local; do
  [[ "$(git config --"$s" user."$v")" != "${!v}" ]] && \
    git config --"$s" user."$v" "${!v}"; done; done
    
  git pull -q
  git add .
  if ! git diff --cached --quiet; then
    git commit --quiet -m "Bumped: v$LATEST_VER"
    git push --quiet
  fi
}

CURR_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
source "$CURR_DIR/printer.sh"
FUNC_SH="$CURR_DIR/func.sh" BUILD_SH="$CURR_DIR/build.sh"
touch "$BUILD_SH" "$FUNC_SH"

DIST_OWNER="MasterZeeno" DIST_REPO="fancy"
DIST_EMAIL="${DIST_OWNER,,}@outlook.com"
SRC_OWNER="sharkdp" SRC_REPO="pastel"

print_update_msg "checking updates for" 2

SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
LATEST_VER=$(get_ver "$SRC_TOML")
if [[ "$1" == '-f' ]]; then
  CURRENT_VER=0
else
  CURRENT_VER=$(get_ver "$BUILD_SH")
fi

if ! printf '%s\n' "$CURRENT_VER" "$LATEST_VER" | sort -V | tail -n1 | grep -xq "$CURRENT_VER"; then
  
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
  
  cat "$FUNC_SH" >> "$BUILD_SH"
  
  if [[ -s "$BUILD_SH" ]]; then
    {
      git clone -q https://github.com/termux/termux-packages.git
      cd termux-packages
      ./scripts/setup-android-sdk.sh
      ./scripts/setup-ubuntu.sh
      mkdir -p "$CURR_DIR/output"
      TERM='xterm-256color' ./build-package.sh -o "$CURR_DIR/output" "$CURR_DIR"
    } || exit 1
    print_update_msg "updated"
    git_push_tag
  fi
fi

cd "$CURR_DIR"
exit 0



