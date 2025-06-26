TERMUX_PKG_DESCRIPTION="A command-line tool to generate, analyze, convert and manipulate colors"
TERMUX_PKG_SHA256="823b3c44a10235372fa55b5fa1d5c5565bc8ffb19a8d85846a45b2142ae1765a"
TERMUX_PKG_SRCURL="https://github.com/sharkdp/pastel/archive/refs/heads/master.zip"
TERMUX_PKG_MAINTAINER="MasterZeeno <masterzeeno@outlook.com>"
TERMUX_PKG_HOMEPAGE="https://github.com/MasterZeeno/fancy"
TERMUX_PKG_LICENSE_FILE="LICENSE-MIT, LICENSE-APACHE"
TERMUX_PKG_LICENSE="MIT/APACHE"
TERMUX_PKG_BUILD_IN_SRC="true"
TERMUX_PKG_AUTO_UPDATE="true"
TERMUX_PKG_REPLACES="pastel"
TERMUX_PKG_VERSION="0.10.0"
TERMUX_PKG_BREAKS="pastel"

termux_step_post_get_source() {
  local DIST_REPO_OWNER="${TERMUX_PKG_MAINTAINER%% *}"
  local DIST_REPO_NAME="${TERMUX_PKG_NAME}"
  local SRC_REPO_OWNER="${TERMUX_PKG_SRCURL:19:7}"
  local SRC_REPO_NAME="${TERMUX_PKG_BREAKS}"

  case_fix() {
    local str="${1:?}"
    local idx="${2:-${#str}}"
    
    case "${str}" in "${DIST_REPO_OWNER}")
      echo "${str}"; return ;; esac
      
    echo "${str}" | sed -E "s/^(.{0,${idx}})/\U\1/"
  }

  print_msg() {
    (($#)) || return
    local old new file head="${1:?}"
    if [[ $# -gt 1 ]]; then
      old="${1:?}" new="${2:?}"
      file="${3:-}" head='success'
    fi

    local R=$'\e[0m'
    local I=$'\uf00c' D=$'\uea83' S=$'\ueb8d' F=$'\uf4a5'
    local DG=$'\e[2;32m' BG=$'\e[1;32m' BY=$'\e[1;33m'
    local DIRXPR=$(printf "s|%s|${BY}\$%s${BG}|" "${TERMUX_PKG_SRCDIR}" 'SRCDIR')
      
    printf " ${BG}%s${R}\n" "${I} ${head^}"
    [[ $# -eq 1 ]] && { sleep 1; clear; return; }
    
    local icon="${S}" key='string'
    local -a paths=('file')
    
    if [[ -z ${file:-} ]]; then
      [[ -d ${old} ]] && \
        icon="${D}" || icon="${F}"
      key='path' paths=('old' 'new')
    fi

    for v in "${paths[@]}"; do
      local -n var="${v}"
      var="$(realpath -mPq "${var}" \
        | sed "${DIRXPR}")"
    done

    for v in {old,new,file}; do
      local -n var="${v}"; [[ -z ${var:-} ]] && continue
      case "${v}" in file) icon="${F}"; key='path' ;; esac
      printf " ${DG}%s:${R} ${BG}%s${R}\n" \
        "${icon} ${v^} ${key^}" "${var}"
    done
    
    echo; sleep 0.32
  }

  clear
  rm -rf "${TERMUX_PKG_SRCDIR}"/.git*
  for prop in REPO_{OWNER,NAME}; do
    for p in {SRC,DIST}; do
      local -n "${p}=${p}_${prop}"
    done

    print_msg "Renaming and replacing [${SRC}] to [${DIST}]..."

    find -P "${TERMUX_PKG_SRCDIR}" -mindepth 1 -readable \
      -writable ! -name '.*' | while IFS= read -r ITEM; do
      for i in {0,1,${#SRC}}; do
        local SRC_CASED=$(case_fix "${SRC}" $i)
        local DIST_CASED=$(case_fix "${DIST}" $i)

        if [[ ${ITEM} == *"${SRC_CASED}"* ]]; then
          local NEW_NAME="${ITEM//${SRC_CASED}/${DIST_CASED}}"
          mv -f "${ITEM}" "${NEW_NAME}"; ITEM="${NEW_NAME}"
          print_msg "${ITEM}" "${NEW_NAME}"
        fi

        if [[ -f ${ITEM} ]]; then
          local MIMETYPE=$(file --mime-type -b "${ITEM}")
          if [[ ${MIMETYPE} == text/* ]]; then
            if [[ ${ITEM##*.} == toml ]]; then 
              local AUTHOR=$(grep -iom1 'authors.*' "${ITEM}" | sed -E 's|.*"(.*)".*|\1|')
              if [[ ${AUTHOR} != ${TERMUX_PKG_MAINTAINER} ]]; then
                sed -Ei "s|(authors.*\").*(.*\")|\1${TERMUX_PKG_MAINTAINER}\2|" "${ITEM}"
                print_msg "${AUTHOR}" "${TERMUX_PKG_MAINTAINER}" "${ITEM}"
              fi
            fi
            if grep -q "${SRC_CASED}" "${ITEM}"; then
              sed -i "s/${SRC_CASED}/${DIST_CASED}/g" "${ITEM}"
              print_msg "${SRC_CASED}" "${DIST_CASED}" "${ITEM}"
            fi
          fi
        fi
      done
    done
  done

  print_msg 'Starting build...'
}

termux_step_pre_configure() {
  termux_setup_rust
  : "${CARGO_HOME:=${HOME}/.cargo}"
  export CARGO_HOME
  cargo fmt -- --check
  cargo clippy --locked --all-targets
  cargo test --locked
  cargo fetch --locked --target "${CARGO_TARGET_NAME}"
}

termux_step_make() {
  SHELL_COMPLETIONS_DIR="${TERMUX_PKG_BUILDDIR}/completions" \
    cargo build --jobs "${TERMUX_PKG_MAKE_PROCESSES}" \
      --locked --target "${CARGO_TARGET_NAME}" --release
}

termux_step_make_install() {
  local -A _SHELLS=(
    [zsh]='/site-functions'
    [bash]='-completion/completions'
    [fish]='/vendor_completions.d' )

  install -Dm755 -t "${TERMUX_PREFIX}/bin" \
    "target/${CARGO_TARGET_NAME}/release/${TERMUX_PKG_NAME}"

  for _SHELL in "${!_SHELLS[@]}"; do local _FILE
    case "${_SHELL}" in zsh) _FILE="_${TERMUX_PKG_NAME}" ;;
      *) _FILE="${TERMUX_PKG_NAME}.${_SHELL}" ;; esac
      
    install -Dm600 "${TERMUX_PKG_BUILDDIR}/completions/${_FILE}" \
      "${TERMUX_PREFIX}/share/${_SHELL}${_SHELLS[$_SHELL]}/${_FILE}"
  done
}
