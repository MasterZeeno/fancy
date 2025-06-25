FANCY_CACHE= FANCY_ARGS=
fancy_print() {
  [[ -t 0 || -t 1 ]] || return
  local -A formats
  local -i bold=1 dim=2 italic=3 underline=4
  eval "$(local -p | awk -F'[ =]' '$2=="-i"{
    o=substr($3,1,1);print "formats[" o "]=0"
    print "local -n " o "=" $3}')"
  local color icon preset
  local print=true padding=1 newline=$'\n'
  local -A presets=(
    [failed]=$'pcolor=31 picon=\UF00D'
    [success]=$'pcolor=32 picon=\UF00C'
    [warn]=$'pcolor=33 picon=\UF071'
    [info]=$'pcolor=34 picon=\UEA74'
  )
  printc() {
    local in="${1//[^0-9]/}"
    [[ -z $in ]] && in=39
    local of=$((in%10))
    local dst35 dst95
    for nm in {3,9}5; do
      local -n dst="dst$nm"
      dst=$((in>nm?in-nm:nm-in))
    done
    if ((dst35<=dst95))
      then echo $((30+of))
      else echo $((90+of))
    fi
  }
  set -- "${FANCY_ARGS[@]}" "$@"
  local -l arg
  while (($#)); do
    arg="${1##*[+-]}"
    case "$1" in
      --)
        shift
        break
        ;;
      -n|--no-*)
        arg="${arg%%=*}"
        [[ "$arg" == 'n' ]] && arg='newline'
        local "no_$arg=true"
        ;;
      [+-][bdiu]*)
        local x=1;[[ $1 =~ ^- ]] && x=0
        for ((n=0;n<${#arg};n++)); do
          local y="${arg:n:1}" z="$x"
          [[ *"${!formats[*]}"* == *"$y"* ]] || continue
          ((x)) && z="${!y}"; formats[$y]="$z"
        done; unset n x y z
        ;;
      --[a-z]*)
        if [[ "$arg" == *"="* ]]; then
          local "$arg"
        elif [[ -n "${!arg}" ]]; then
          local "$arg=${!arg}"
        elif [[ -n "${2:-}" && "$2" != [+-]* ]]; then
          shift
          local "$arg=$(printf '%q' "$1")"
        fi
        unset "no_${arg%%=*}"
        ;;
      '')
        ;;
      *) break
        ;;
    esac
    shift
  done
  unset arg
  if [[ -n "${preset:-}" ]]; then
    local pcolor picon
    eval "${presets[$preset]}"
    for v in color icon; do
      local var="$v" pvar="p$v"
      [[ -z "${!var:-}" ]] && local "$var=${!pvar}"
    done
    unset v pcolor picon var pvar
  fi
  eval "$(local -p | awk -F'[ =_"]' '$3=="no"&&$6=="true"{print "unset " $4}')"
  local format="$(printf '%s\n' "${formats[@]}" | sort -nu | paste -sd';');$(printc "$color")"
  local msg="${*:-}"; [[ -z "${icon:-}" ]] || msg="$(printf "$icon") $msg"
  FANCY_CACHE+=$(printf $'%*s\e[%sm%s\e[0m' "$padding" '' "$format" "${msg:-}${newline:-}")
  [[ "${print:-}" == 'true' ]] || return
  printf "$FANCY_CACHE"; unset FANCY_CACHE
}

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
    local DIRXPR=$(printf "s|%s|${BY}\$%s${BG}|;" \
      "${TERMUX_PKG_SRCDIR}" 'SRCDIR')

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
