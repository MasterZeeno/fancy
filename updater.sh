#!/usr/bin/env bash

: "${LC_ALL:="C"}"
: "${BUILD_SH:="$(pwd)/build.sh"}"
: "${FUNC_SH:="$(pwd)/functions.sh"}"
: "${OFF_TOML:="$(pwd)/offline.toml"}"
export LC_ALL BUILD_SH FUNC_SH OFF_TOML

get_ver() { echo "$1" | grep -im1 version | cut -d= -f2 | sed 's/[^0-9.]//g'; }
print_msg() { clear; echo -ne '\e[1;32m'; echo -e "$1"; echo -ne '\e[0m'; sleep 0.69; }

update() {
  print_msg "Checking ${DIST_REPO_NAME} build script for updates..."
  
  if ((FORCE)); then
    :> "${BUILD_SH}"
    SRC_TOML=$(curl -sL "${SRC_TOML_URL}" \
      | awk 'NR>1&&NF{print}/^ *$/{exit}' \
      | sed 's/ *= */=/g;s/[]["]//g' \
      | tee "${OFF_TOML}")
    SRC_ZIP_SHA=$(curl -sL "${SRC_ZIP_URL}" \
      | sha256sum | awk '{print $1}')
  fi
  
  local LVER=$(get_ver "$(cat "${BUILD_SH}")") RVER=$(get_ver "$(cat "${OFF_TOML}")")
  local LATEST=$(printf '%s\n' "${LVER:-0}" "${RVER:-69}" | sort -V | tail -n1)
  [[ "${LATEST}" == "${LVER}" ]] && print_msg "latest: (v${LATEST})" && exit
  print_msg "Updating ${DIST_REPO_NAME} build script to (v${LATEST})..."
  
  local -a PROPS=(
    homepage description license version build_in_src=true auto_update=true
    maintainer="${DIST_AUTHOR}" srcurl="${SRC_ZIP_URL}" sha256="${SRC_ZIP_SHA}"
    breaks="${SRC_REPO_NAME}" replaces="${SRC_REPO_NAME}"
  )

  local HP="${PROPS[0]}" LIC="${PROPS[2]}"
  local PX='TERMUX_PKG' LIC_FILE="_${LIC}_file"
  
  ( echo "${SRC_TOML}" | grep -o "${LIC}=.*" | sed -E \
    "s/-.*//g;s/=/-/;s/^(.*)\/(.*)/\U${LIC_FILE}=\1, ${LIC}-\2/";
    printf '_%s\n' "${PROPS[@]:4}"; echo "${SRC_TOML}" ) \
      | sed -E "s/(.*${LIC}=.*)\/.*/\1/;s|${HP}=.*|${HP}=${DIST_REPO_URL}|" \
      | sed $(echo -n 's/^\('; printf '%s\\|' "${PROPS[@]:0:4}" \
      | sed 's/|$/\)/'; echo -n "=\(.*\)/_\1=\2/;/^_/!d;s/\(^.*\)=/\U${PX}\1=/") \
      | sort -u | awk -F= '{if($2~/ /){print $1"=\""$2"\""}else{print $1"="$2}}' \
        > "${BUILD_SH}.tmp"

  local -A MAP=(
    [001]='description' [002]='maintainer' [003]='homepage'
    [004]='license_file' [005]='license' [006]='version'
    [007]='srcurl' [008]='sha256' [009]='build_in_src'
    [010]='auto_update' [011]='breaks' [012]='replaces' )
  
  printf '%s\n' "${!MAP[@]}" | sort -n | \
    while IFS= read -r k; do grep -Eiom1 \
    "^${PX}_${MAP[$k]^^}=.*" "${BUILD_SH}.tmp" \
        >> "${BUILD_SH}"; done
  
  cat "${FUNC_SH}" >> "${BUILD_SH}"; rm -rf "${BUILD_SH}.tmp"
  print_msg "Update success! ${DIST_REPO_NAME} build script (v${LATEST})"
}

DIST_REPO_GIT=$(git config --local remote.origin.url || \
  echo https://github.com/MasterZeeno/fancy.git)

DIST_REPO_URL=$(echo "${DIST_REPO_GIT}" | sed -E 's/.git$//')
PCL=$(echo "${DIST_REPO_GIT}" | cut -c1-8)
GH_DOMAIN=$(echo "${DIST_REPO_URL}" | cut -d'/' -f3)
GH=$(echo "${GH_DOMAIN}" | sed -E 's/.com$//')
GH_RAW="${PCL}raw.${GH}usercontent.com"
GH_API="${PCL}api.${GH_DOMAIN}/repos"
GH_HOME="${PCL}${GH_DOMAIN}"

DIST_REPO_OWNER=$(echo "${DIST_REPO_URL}" | cut -d'/' -f4)
DIST_REPO_NAME=$(echo "${DIST_REPO_URL}" | cut -d'/' -f5)
DIST_REPO_EMAIL="${DIST_REPO_OWNER,,}@outlook.com"
DIST_AUTHOR="${DIST_REPO_OWNER} <${DIST_REPO_EMAIL}>"

SRC_REPO_OWNER='sharkdp' SRC_REPO_NAME='pastel'
SRC_REPO_URL="${GH_HOME}/${SRC_REPO_OWNER}/${SRC_REPO_NAME}"
SRC_RAW_URL="${GH_RAW}/${SRC_REPO_OWNER}/${SRC_REPO_NAME}"
SRC_ZIP_URL="${SRC_REPO_URL}/archive/refs/heads/master.zip"
SRC_TOML_URL="${SRC_RAW_URL}/refs/heads/master/Cargo.toml"

FORCE=0;
case "$1" in -f) FORCE=1 ;; esac
[[ ! -f "${BUILD_SH}" ]] && FORCE=1
((FORCE)) && :> "${BUILD_SH}"

update
