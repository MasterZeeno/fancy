#!/bin/bash

if [ -z "${BASH_VERSION:-}" ]; then
  echo "The 'update.sh' script must be run from a 'bash' shell."
  return 64 2>/dev/null || exit 64
fi

MAIN_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT_DIR="$MAIN_DIR/output"; rm -rf "$OUT_DIR"

for v in {dist,src,build}.{owner,repo,email} {funcs,build}.sh; do
  val="" condition=false
  if [[ $v =~ \.sh$ ]]; then
    val="$MAIN_DIR/$v"
    [[ -s "$val" ]] && condition=true
  else
    val=$(git config --file "$MAIN_DIR/.cfg" $v)
    [[ -n "$val" ]] && condition=true
  fi
  
  if [[ "$condition" == "true" ]]; then
    declare -u var="${v/./_}"
    declare "${var^^}=$val"
  else
    if [[ $v =~ \.sh$ || $v =~ ^[dsb]*(owner|repo)$ || $v =~ ^d*email$ ]]; then
      echo "Variable '$var' is necessary, provide a valid value."
      return 1 2>/dev/null || exit 1
    fi
  fi
  unset val var condition
done

source "$FUNCS_SH"

if [[ "$(uname -o)" == "Android" && "${PREFIX:-}" == *"com.termux"* ]]; then
  SUDO="" RUNNER="termux"
  source "$PREFIX/bin/termux-setup-package-manager" || true
else
  [[ $(id -u) -eq 0 ]] || SUDO="sudo"
  if command -v apt &>/dev/null; then
    RUNNER="ubuntu" TERMUX_APP_PACKAGE_MANAGER="apt"
  elif command -v pacman &>/dev/null; then
    RUNNER="archlinux" TERMUX_APP_PACKAGE_MANAGER="pacman"
  fi
fi

if [[ -z "${TERMUX_APP_PACKAGE_MANAGER:-}" ]]; then
  fancy_print --preset=failed +b "Error: no package Manager defined"
  return 1 2>/dev/null || exit 1
fi

install_pkgs() {
  local old_args=("${FANCY_ARGS[@]}")
  local pkg retry status
  echo
  
  while (($#)); do
    [[ -z "${1:-}" ]] && continue
    pkg="$1" retry=0 status="success"
    while ! command -v "$pkg" &>/dev/null; do
      case "$TERMUX_APP_PACKAGE_MANAGER" in
        apt)
          $SUDO apt-get -yq update &>/dev/null
          $SUDO env DEBIAN_FRONTEND=noninteractive \
            apt-get install -yq --no-install-recommends "$pkg" &>/dev/null
          ;;
        pacman)
          [[ "$pkg" == "gh" ]] && pkg="github-cli"
          $SUDO pacman -Syq --needed --noconfirm "$pkg" &>/dev/null
          ;;
      esac
      ((retry++)); if ((retry>3)); then status="failed"; break; fi
    done
    
    FANCY_ARGS=(--no-print --preset="$status")
    fancy_print -n +d "Install $status:"
    fancy_print --print --no-icon +b "$pkg"
    
    [[ "$status" == "failed" ]] && exit 1
    shift
  done
  
  FANCY_ARGS=("${old_args[@]}")
}

get_ver() { ([[ -f "$1" ]] && cat "$1" || echo "$1") | grep -iom1 'version[ =].*' | grep -Eo '[0-9.]+'; }
print_update_msg() {
  local msg="${1:?}" slp="${2:-0}" bmsg="$DIST_OWNER/$DIST_REPO"
  [[ -z "${LATEST_VERSION:-}" ]] || bmsg+=" to v$LATEST_VERSION"
  
  FANCY_ARGS=(--no-print)
  [[ "${msg,,}" =~ ^updated ]] && \
    FANCY_ARGS+=(--preset=success) || \
      FANCY_ARGS+=(--color=36)
  
  echo
  fancy_print -n +d "${msg^}:" 
  fancy_print --print --no-icon +b "$bmsg"
  sleep "$slp.69"
}

build_fancy() {
  mkdir -p "$OUT_DIR"
  
  [[ -d "$MAIN_DIR/$BUILD_REPO" ]] || \
    git clone --quiet "https://github.com/$BUILD_OWNER/$BUILD_REPO.git"
  cd "$MAIN_DIR/$BUILD_REPO" && git pull --quiet &>/dev/null || exit 1
  
  export TERM="${TERM:-"xterm-256color"}"
  
  cd "$MAIN_DIR/$BUILD_REPO/scripts"
  
  source properties.sh &>/dev/null
  if [[ "$RUNNER" != "termux" ]]; then
    [[ ! -d "${NDK:-}" || ! -d "${ANDROID_HOME:-}" ]] \
      && source setup-android-sdk.sh &>/dev/null
  fi
  
  source setup-$RUNNER.sh &>/dev/null

  if [[ "$RUNNER" == "archlinux" ]]; then
    $SUDO sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    local -a packages=(ncurses5-compat-libs makedepend python2)
    local -a install_opts=(--noconfirm --needed)
    if command -v paru &>/dev/null; then
      $SUDO paru -S "${install_opts[@]}" "${packages[@]}" &>/dev/null
    elif command -v yay &>/dev/null; then
      $SUDO yay -S "${install_opts[@]}" "${packages[@]}" &>/dev/null
    else
      for package in "${packages[@]}"; do
        git clone --quiet https://aur.archlinux.org/"$package"
        cd "$package" || exit 1
        makepkg -si --skippgpcheck "${install_opts[@]}" &>/dev/null
        cd - || exit 1
        rm -rf "$package"
      done
    fi
  fi

  cd "$MAIN_DIR/$BUILD_REPO" && ./clean.sh &>/dev/null
  
  ./build-package.sh -f -q -o "$OUT_DIR/" "$MAIN_DIR"
  
  find "$OUT_DIR" -iname '*.deb' | grep -q . && publish_fancy
}

gh_login() {
  if [[ "$(gh api user --jq .login)" != "$DIST_OWNER" ]]; then
    gh auth logout &>/dev/null
    
    local status="success"
    cd "$MAIN_DIR"
    
    for var in name email; do
      local val=$(git config --file "$MAIN_DIR/.cfg" user.$var)
      for flag in global local; do
        [[ "$(git config --$flag user.$var)" != "$val" ]] \
          && git config --$flag user.$var "$val"
      done
    done
    
    echo
    FANCY_ARGS=(--no-print --color=36)
    fancy_print +d -n "Logging into"
    fancy_print +b --print "Github"
    
    if [[ -z "${GH_TOKEN:-}" ]]; then
      local token
      while true; do
        fancy_print -n "*GH Auth Token: "
        read -r token
        token="${token//[^a-zA-Z0-9]/}"
        [[ -n "$token" ]] && break
      done
      export GH_TOKEN="$token"
    fi
    
    local try=0
    gh config set -h github.com git_protocol https
    while ! gh auth status &>/dev/null; do
      echo "$GH_TOKEN" | gh auth login --with-token &>/dev/null
      ((try++)) && ((try>3)) && { status="failed"; break; }
    done
    
    [[ $? -eq 1 ]] && status="failed"
    
    FANCY_ARGS=(--preset="$status" +b)
    echo; fancy_print "Login $status"
    [[ "$status" == "failed" ]] && exit 1
  fi
}

publish_fancy() {
  local tag="v${1:-$LATEST_VERSION}"
  cd "$MAIN_DIR"
  
  if git ls-remote --tags origin | grep -q "refs/tags/$tag$"; then
    git tag | grep -q "^$tag$" && git tag -d "$tag"
    git rev-parse -q --verify "refs/tags/$tag" &>/dev/null \
      && git push origin ":refs/tags/$tag"
    gh release view "$tag" &>/dev/null && gh release delete "$tag" -y
  fi
  
  git tag "$tag"
  git push --quiet origin "$tag"
  gh release create "$tag" \
    --title "$DIST_REPO $tag" \
    --target "$(git rev-parse HEAD)" \
    --repo "$DIST_OWNER/$DIST_REPO" >/dev/null
    
  find "$OUT_DIR" -type f -iname '*.deb' \
    | while IFS= read -r file; do
      gh release upload "$tag" "$file" --clobber >/dev/null \
        && status="success" || status="failed"
        
      FANCY_ARGS=(--no-print --preset="$status")
      fancy_print -n +d "Upload $status:"
      fancy_print --print +b --no-icon "$file"
  done
}

install_pkgs curl gh git jq tar unzip zip
print_update_msg "checking updates for" 2
gh_login && git pull --quiet &>/dev/null || exit 1

SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
LATEST_VERSION=$(get_ver "$SRC_TOML") CURRENT_VERSION=0
[[ "$1" == '-f' ]] || CURRENT_VERSION=$(get_ver "$BUILD_SH")
if ! printf '%s\n' "$CURRENT_VERSION" "$LATEST_VERSION" | sort -V | tail -n1 | grep -xq "$CURRENT_VERSION"; then
  print_update_msg "updating" 1; echo
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
    
    if [[ -s "$BUILD_SH" ]]; then
      cd "$MAIN_DIR" && git add .
      if ! git diff --cached --quiet; then
        git commit --quiet -m "Bumped: v$LATEST_VER"
        git push --quiet
      fi
      
      build_fancy
    fi
fi

print_update_msg "updated"
return 0 2>/dev/null || exit 0









