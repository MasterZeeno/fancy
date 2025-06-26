#!/bin/bash

if [ -z "${BASH_VERSION:-}" ]; then
  echo "The 'update.sh' script must be run from a 'bash' shell."
  return 64 2>/dev/null || exit 64
fi

clear
MAIN_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT_DIR="$MAIN_DIR/output"; rm -rf "$OUT_DIR"

for v in {dist,src,build}.{owner,repo,email} {funcs,build}.sh; do
  declare val condition=false
  if [[ $v =~ \.sh$ ]]; then
    val="$MAIN_DIR/$v"
    [[ -s "$val" ]] && condition=true
  else
    val=$(git config --file "$MAIN_DIR/.gitconfig" $v)
    [[ -n "$val" ]] && condition=true
  fi
  
  if [[ "$condition" == "true" ]]; then
    declare -u var="${v/./_}"
    declare "${var^^}=$val"
  else
    if [[ $v =~ \.sh$ || $v =~ ^[dsb]*(owner|repo)$ || $v =~ ^d*email$ || $v =~ ^g*token$ ]]; then
      echo "Variable '$var' is necessary, it should not be empty."
      return 1 2>/dev/null || exit 1
    fi
  fi
done
unset val var condition
source "$FUNCS_SH"

if [[ "$(uname -o)" == "Android" && "${PREFIX:-}" == *"com.termux"* ]]; then
  SUDO=""
  RUNNER="termux"
  source "$PREFIX/bin/termux-setup-package-manager" || true
else
  [[ $(id -u) -eq 0 ]] || SUDO="sudo"
  if command -v apt &>/dev/null; then
    RUNNER="ubuntu"
    TERMUX_APP_PACKAGE_MANAGER="apt"
  elif command -v pacman &>/dev/null; then
    RUNNER="archlinux"
    TERMUX_APP_PACKAGE_MANAGER="pacman"
  fi
fi

if [[ -z "${TERMUX_APP_PACKAGE_MANAGER:-}" ]]; then
  fancy_print --preset=failed +b "Error: no package Manager defined"
  return 1 2>/dev/null || exit 1
fi

install_pkgs() {
  local retry=0
  local old_args=("${FANCY_ARGS[@]}")
  while (($#)); do
    if ! command -v "$1" &>/dev/null; then
      case "$TERMUX_APP_PACKAGE_MANAGER" in
        apt)
          $SUDO apt-get -yq update &>/dev/null
          $SUDO env DEBIAN_FRONTEND=noninteractive \
            apt-get install -yq --no-install-recommends "$1" &>/dev/null
          ;;
        pacman)
          $SUDO pacman -Syq --needed --noconfirm "$1" &>/dev/null
          ;;
      esac
    fi
    FANCY_ARGS=(--no-print)
    if command -v "$1" &>/dev/null; then
      FANCY_ARGS+=(--preset=success)
      fancy_print -n +d "Installed:"
      fancy_print --print --no-icon +b "$1"
      retry=0
      shift
    else
      ((retry++))
      if ((retry>3)); then
        FANCY_ARGS+=(--preset=failed)
        fancy_print -n +d "Failed to install:"
        fancy_print --print --no-icon +b "$1"
        return 1 2>/dev/null || exit 1
      else
        FANCY_ARGS+=(--preset=warn)
        fancy_print -n +d "Retrying ($retry/3):"
        fancy_print --print --no-icon +b "$1"
      fi
    fi
  done
  FANCY_ARGS=("${old_args[@]}")
  sleep 2
}

get_ver() { ([[ -f "$1" ]] && cat "$1" || echo "$1") | grep -iom1 'version[ =].*' | grep -Eo '[0-9.]+'; }
print_update_msg() {
  local msg="${1:?}" slp="${2:-0}"
  local bmsg="$DIST_OWNER/$DIST_REPO"
  [[ -z "${LATEST_VERSION:-}" ]] || bmsg+=" v$LATEST_VERSION"
  
  FANCY_ARGS=(--no-print)
  if [[ "${msg,,}" =~ ^updated ]]; then
    FANCY_ARGS+=(--preset=success)
  else
    FANCY_ARGS+=(--color=36)
  fi
  
  clear
  fancy_print -n +d "${msg^}" 
  fancy_print --print --no-icon +b "$bmsg"
  sleep "$slp.69"
}

build_fancy() {
  clear; mkdir -p "$OUT_DIR"
  local BUILD_GIT_URL="https://github.com/$BUILD_OWNER/$BUILD_REPO.git"
  if [[ -d "$MAIN_DIR/$BUILD_REPO" ]]; then git clone "$BUILD_GIT_URL"
    else cd "$MAIN_DIR/$BUILD_REPO"; git pull --quiet; fi
  : "${TERM:=xterm-256color}"; export TERM
  cd "$MAIN_DIR/$BUILD_REPO/scripts"; ./setup-$RUNNER.sh
  cd "$MAIN_DIR/$BUILD_REPO" && ./build-package.sh -f -q -o "$OUT_DIR/" "$MAIN_DIR"
  [[ $(ls "$OUT_DIR"/ | wc -l) -gt 1 ]] && publish_fancy
}

login_gh() {
  install_pkgs gh
  
  [[ "$(gh api user --jq .login)" == "$name" ]] && return 0
  
  FANCY_ARGS=(--no-print --color=36)
  fancy_print +d -n "Logging into"
  fancy_print +b --print "Github"
  
  local token try=0
  while true; do
    fancy_print -n "*GH Auth Token: "
    read -r token
    token="${token#"${token%%[![:space:]]*}"}"
    token="${token%"${token##*[![:space:]]}"}"
    [[ -n "$token" ]] && break
  done
  
  gh config set -h github.com git_protocol https
  while ! gh auth status &>/dev/null; do
    echo "$token" | gh auth login --with-token &>/dev/null
    ((try++)) && ((try>3)) && return 1
  done
  return 0
}

publish_fancy() {
  local tag="${1:-"v$LATEST_VERSION"}"
  local remote="${2:-"origin"}"
  
  local result
  [[ "$(gh api user --jq .login)" == "$name" ]] \
    && result="success" || result="failed"
  
  clear
  FANCY_ARGS=(--no-print --preset="$result")
  fancy_print +b "Login $result"
  
  FANCY_ARGS=(--no-print --color=36)
  fancy_print -n +d "Checking for existing tag:"
  fancy_print --print +b "'$tag'"
  sleep 2

  if git ls-remote --tags "$remote" | grep -q "refs/tags/$tag$"; then
    fancy_print --print +d "Cleaning up..."
    
    FANCY_ARGS=(--no-print --preset=success)
    if git tag | grep -q "^$tag$"; then
      git tag -d "$tag"
      fancy_print -n +d "Deleted local tag:"
      fancy_print --print +b "'$tag'"
    fi
    
    if git rev-parse -q --verify "refs/tags/$tag" &>/dev/null; then
      git push "$remote" ":refs/tags/$tag"
      fancy_print -n +d "Deleted remote tag:"
      fancy_print --print +b "'$tag'"
    fi
    
    if gh release view "$tag" &>/dev/null; then
      gh release delete "$tag" -y
      fancy_print -n +d "Deleted GitHub release:"
      fancy_print --print +b "'$tag'"
    fi
  fi
  
  git tag "$tag"
  git push origin "$tag"
  gh release create "$tag" \
    --title "Latest release: $tag" \
    --target "$(git rev-parse HEAD)" \
    --repo "$DIST_OWNER/$DIST_REPO" >/dev/null
    
  for file in "$OUT_DIR"/*; do
    if [[ -f "$file" ]]; then
      clear
      FANCY_ARGS=(--no-print --preset=info)
      fancy_print -n +d "Uploading"
      fancy_print --print +b "$file"
      gh release upload "$tag" "$file" --clobber >/dev/null
      sleep 1
      FANCY_ARGS=(--preset=success +b)
      fancy_print "Success!"
    fi
  done
}

install_pkgs curl git awk sed grep sha256sum jq
print_update_msg "checking updates for" 2

SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
LATEST_VERSION=$(get_ver "$SRC_TOML") CURRENT_VERSION=0
[[ "$1" == '-f' ]] || CURRENT_VERSION=$(get_ver "$BUILD_SH")
if ! printf '%s\n' "$CURRENT_VERSION" "$LATEST_VERSION" | sort -V | tail -n1 | grep -xq "$CURRENT_VERSION"; then
  
  print_update_msg "updating" 1
  
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
  
  awk 'BEGIN{n=0}/^ *$/{n++}n>=1' "$FUNCS_SH" >> "$BUILD_SH"
  [[ -s "$BUILD_SH" ]] && build_fancy
fi

# print_update_msg "updated"
return 0 2>/dev/null || exit 0









