#!/usr/bin/env bash

get_ver() { (cat "$1" 2>/dev/null || echo "$1") | grep -iom1 'version[ =].*' | sed 's|[^0-9.]||g'; }
print_msg() { clear; sleep 0.69; printf $'\n\e[1;32m \uf09b %s\e[0m\n' "${1^}"; sleep 0.69; }

DIST_OWNER="MasterZeeno" DIST_REPO="fancy" SRC_OWNER="sharkdp" SRC_REPO="pastel"
SRC_ZIP_URL="https://github.com/$SRC_OWNER/$SRC_REPO/archive/refs/heads/master.zip"
FUNC_SH="$(pwd)/func.sh" BUILD_SH="$(pwd)/build.sh"; touch "$BUILD_SH" "$FUNC_SH"
BASE_MSG="$DIST_OWNER/$DIST_REPO"

print_msg "checking updates for: $BASE_MSG..."; sleep 2
SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
CURRENT_VER=$(get_ver "$BUILD_SH") LATEST_VER=$(get_ver "$SRC_TOML")
BASE_MSG+=" to: v$LATEST_VER";case "${1,,}" in -f|--force) CURRENT_VER=0 ;; esac
printf '%s\n' "$CURRENT_VER" "$LATEST_VER" \
  | sort -V | tail -n1 | grep -xq "$CURRENT_VER" && \
    sleep 1 && print_msg "updated: $BASE_MSG" && exit

print_msg "updating: $BASE_MSG..."

SRC_ZIP_SHA=$(curl -fsSL "${SRC_ZIP_URL}" | sha256sum | awk '{print $1}')

{ echo "$SRC_TOML" \
    | awk 'NR==1{next}/^ *$/{exit}NF{gsub(/\[|\]|"/,"")gsub(/ += +/,"=");print}' \
    | sed -E -e "s/^(version|description)/_\1/" \
      -e "s|^authors=.*|_maintainer=$DIST_OWNER <${DIST_OWNER,,}@outlook.com>|" \
      -e "s|^(homepage)=.*|_\1=https://github.com/$DIST_OWNER/$DIST_REPO|" \
      -e "/^license/{s|[0-9.-]||g;s|.*|_\U&|;p;s|_(.*)=(.*)/(.*)|_\1_file=\1-\2, \1-\3|}"
  printf '_%s=%s\n' \
    srcurl "$SRC_ZIP_URL" sha256 "$SRC_ZIP_SHA" \
    breaks "$SRC_REPO" replaces "$SRC_REPO" \
    build_in_src true auto_update true
} | sed -E "/^_/!d;s|(.*)=|\Utermux_pkg\1=|;s|=(.*)|='\1'|g" > "$BUILD_SH"

cat "$FUNC_SH" >> "$BUILD_SH"
(git pull; git add .; git commit -m "Bumped: $BASE_MSG"; git push) &>/dev/null
print_msg "updated: $BASE_MSG"
