#!/usr/bin/env bash

FANCY_CACHE=
FANCY_ARGS=

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






