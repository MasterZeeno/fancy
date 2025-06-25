#!/usr/bin/env bash

trans_color() {
  local i=${1//[^0-9]/}
  [[ -z $i ]] && i=39
  local o=$((i%10)) b=0
  local c d35 d95

  for n in {3,9}5; do
    local -n d="d$n"
    d=$((i>n?i-n:n-i))
  done
  
  ((d35<=d95)) && \
    c=$((30+o)) || c=$((90+o))
  
  for v in {N,B,D,I}; do
    local -n V=$v; ((b++))
    V=$(printf $'\e[0;%s;%sm' $b $c)
  done
}

print_msg() {
  [[ -t 0 || -t 1 ]] && clear || return
  local msg="${1:?}" head="${2:-}"
  local clr=${3:-} slp=${4:-1}
  local tail= ic=
  
  case "${msg,,}${head,,}" in
    *ing*)
      ic=$' \UF0674 '
      clr=33
      tail='...'
      ;;
    *success*|*updated*)
      ic=$' \UF012C '
      clr=32
      ;;
    *fail*|*error*)
      ic=$' \UF0156 '
      clr=31
      ;;
    *)
      clr=39
      ;;
  esac
  
  trans_color "$clr"
  echo -e "${D} ${msg^} ${B}${ic:-}${head-}${D}${end}"
  sleep $slp
}

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
  
  fancy_print -n +d "${msg^}:" 
  fancy_print --print --no-icon +b "$bmsg"
  sleep "$slp"
}

get_ver() { ([[ -f "$1" ]] && cat "$1" || echo "$1") | grep -iom1 'version[ =].*' | sed 's|[^0-9.]||g'; }

git_push() {
  local name="${1:-$DIST_OWNER}"
  local email="${2:-$DIST_EMAIL}"

  for v in name email; do for s in global local; do
  [[ "$(git config --"$s" user."$v")" != "${!v}" ]] && \
    git config --"$s" user."$v" "${!v}"; done; done
    
  git pull --quiet origin master
  git add -f .
  if ! git diff --cached --quiet; then
    git commit --quiet -m "Bumped: v$LATEST_VER"
    git push --quiet -f origin master
  fi
}

source "$(pwd)/printer.sh"
FUNC_SH="$(pwd)/func.sh" BUILD_SH="$(pwd)/build.sh"
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
  git_push
fi

print_update_msg "updated to latest"





