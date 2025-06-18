#!/usr/bin/env bash

get_ver() { (cat "$1" 2>/dev/null || echo "$1") | grep -iom1 'version[ =].*' | sed 's|[^0-9.]||g'; }
print_msg() { clear; printf $'\n \uf00c \e[1;32m%s\e[0m\n' "$@"; sleep 0.69; }

LC_ALL="C"
FUNC_SH="$(pwd)/func.sh"
BUILD_SH="$(pwd)/build.sh"
touch "$BUILD_SH" "$FUNC_SH"

DIST_OWNER="MasterZeeno" DIST_REPO="fancy" SRC_OWNER="sharkdp" SRC_REPO="pastel"
SRC_ZIP_URL="https://github.com/$SRC_OWNER/$SRC_REPO/archive/refs/heads/master.zip"

print_msg "Checking $DIST_REPO build script for updates..."
SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
CURRENT_VER=$(get_ver "$BUILD_SH") LATEST_VER=$(get_ver "$SRC_TOML")
case "${1,,}" in -f|--force) unset CURRENT_VER ;; esac
printf '%s\n' "${CURRENT_VER:=0}" "${LATEST_VER:=1}" \
  | sort -V | tail -n1 | grep -xq "${CURRENT_VER:=0}" && \
    print_msg "latest: (v${LATEST_VER})" && exit

SRC_ZIP_SHA=$(curl -fsSL "${SRC_ZIP_URL}" | sha256sum | awk '{print $1}')
print_msg "Updating ${DIST_REPO_NAME} build script to (v${LATEST_VER})..."
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

(
  git pull
  git add .
  git commit -m "Bump $DIST_REPO build script (v${LATEST_VER})"
  git push
) 2>/dev/null

print_msg "Update success! $DIST_REPO build script (v${LATEST_VER})"
