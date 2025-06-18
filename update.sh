#!/usr/bin/env bash

get_ver() { ([[ -f "$1" ]] && cat "$1" || echo "$1") | grep -iom1 'version[ =].*' | sed 's|[^0-9.]||g'; }
print_msg() {
  [[ -t 0 || -t 1 ]] && clear || return
  local MSG=${1^} SLP=${2:-1} CLR=32 END="!"
  local VER="${LATEST_VER:-}"
  local REPO_MSG="$DIST_OWNER/$DIST_REPO"
  [[ -n "$VER" ]] && REPO_MSG+=" v$VER"
  case "${MSG,,}" in *ing*) CLR=33; END="..." ;; esac
  printf $'\e[2;%sm %s:\e[0m \e[1;%sm\uf09b %s\e[0m\e[2;%sm%s\e[0m\n' \
    "$CLR" "$MSG" "$CLR" "$REPO_MSG" "$CLR" "$END" && sleep "$SLP"
}

# gh_auto_login() {
  # local name="$DIST_OWNER"
  # local email="$DIST_EMAIL"
  # local token="${3:-$GH_PAT}"

  # if [[ -z "$user" || -z "$email" || -z "$token" ]]; then
    # echo "Usage: gh_auto_login <username> <email> <gh_token>"
    # echo "Or set GIT_USER, GIT_EMAIL, GH_PAT env vars"
    # return 1
  # fi
  
  # for v in name email; do
    # local -n var="$v"
    # for s in global local; do
      # git config --$s user.$v "$var"
    # done
  # done
  
  # # GitHub CLI auth
  # echo "$token" | gh auth login --with-token >/dev/null 2>&1

  # if gh auth status &>/dev/null; then
    # echo "✅ GitHub CLI authenticated as $(gh api user --jq .login)"
  # else
    # echo "❌ GitHub CLI login failed"
    # return 1
  # fi
# }

FUNC_SH="$(pwd)/func.sh" BUILD_SH="$(pwd)/build.sh"
touch "$BUILD_SH" "$FUNC_SH"

DIST_OWNER="MasterZeeno" DIST_REPO="fancy"
DIST_EMAIL="$DIST_OWNER <${DIST_OWNER,,}@outlook.com>"
SRC_OWNER="sharkdp" SRC_REPO="pastel"

print_msg "checking updates for" 2

SRC_TOML=$(curl -fsSL "https://raw.githubusercontent.com/$SRC_OWNER/$SRC_REPO/refs/heads/master/Cargo.toml")
CURRENT_VER=$(get_ver "$BUILD_SH") LATEST_VER=$(get_ver "$SRC_TOML")

[[ "$1" == '-f' ]] && CURRENT_VER=0
if ! printf '%s\n' "$CURRENT_VER" "$LATEST_VER" \
  | sort -V | tail -n1 | grep -xq "$CURRENT_VER"; then

  print_msg "updating"
  
  SRC_ZIP_URL="https://github.com/$SRC_OWNER/$SRC_REPO/archive/refs/heads/master.zip"
  SRC_ZIP_SHA=$(curl -fsSL "${SRC_ZIP_URL}" | sha256sum | awk '{print $1}')
  { echo "$SRC_TOML" \
      | awk 'NR==1{next}/^ *$/{exit}NF{gsub(/\[|\]|"/,"")gsub(/ += +/,"=");print}' \
      | sed -E \
        -e "s/^(version|description)/_\1/" \
        -e "s|^(homepage)=.*|_\1=https://github.com/$DIST_OWNER/$DIST_REPO|" \
        -e "/^license/{s|[0-9.-]||g; s|.*|_\U&|; p; s|_(.*)=(.*)/(.*)|_\1_file=\1-\2, \1-\3|}"
    printf '_%s=%s\n' \
      srcurl "$SRC_ZIP_URL" sha256 "$SRC_ZIP_SHA" maintainer "$DIST_EMAIL" \
      breaks "$SRC_REPO" replaces "$SRC_REPO" build_in_src true auto_update true
  } | sed -E "/^_/!d; s|(.*)=|\Utermux_pkg\1=|;s|=(.*)|=\"\1\"|g" \
    | awk '{print length, $0}' | sort -nr | cut -d' ' -f2- > "$BUILD_SH"
  
  cat "$FUNC_SH" >> "$BUILD_SH"
  
  {
    git pull --quiet
    git add .
  
    if ! git diff --cached --quiet; then
      git commit --quiet -m "Bumped: v$LATEST_VER"
      git push --quiet
    fi
  }
fi

print_msg "updated to latest"





