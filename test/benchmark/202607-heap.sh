#!/usr/bin/bash

if ! declare -F ble/is-function &>/dev/null; then
  function ble/is-function { declare -F "$1" &>/dev/null; }
  function ble/array#push { builtin eval -- "$1"'[${#'"$1"'[@]}]=$2'; }
  function ble/util/print { printf '%s\n' "$1"; }
fi

_ble_heap_vars=(__ble_name __ble_len __ble_less __ble_0ref __ble_iref __ble_jref __ble_kref)

## @fn ble/heap#.initialize name predicate opts
##   @var[out] __ble_name
##   @var[out] __ble_len
##   @var[out] __ble_less
##   @var[out] __ble_0ref __ble_iref __ble_jref __ble_kref
function ble/heap#.initialize {
  if [[ :${3-}: != *:force:* && ( $1 == __ble_* || $1 == *[!_a-zA-Z0-9]* || ! $1 ) ]]; then
    ble/util/print "ble/heap: invalid heap name '$1'" >&2
    __ble_name= __ble_len=0
    return 2
  fi

  __ble_name=$1
  builtin eval '__ble_len=${#'"$__ble_name"'[@]}'
  __ble_0ref=$__ble_name'[0]'
  __ble_iref=$__ble_name'[__ble_i]'
  __ble_jref=$__ble_name'[__ble_j]'
  __ble_kref=$__ble_name'[__ble_j+1]'

  if [[ ${2-} ]]; then
    if [[ $2 == *'$'* ]] && ! ble/is-function "$2"; then
      if [[ :${3-}: == *:reverse:* ]]; then
        __ble_less=$'! {\n'$2$'\n}'
      else
        __ble_less=$2
      fi
    else
      __ble_less[1]=$2
      if [[ :${3-}: == *:reverse:* ]]; then
        __ble_less[0]='! "${__ble_less[1]}" "$1" "$2"'
      else
        __ble_less[0]='"${__ble_less[1]}" "$1" "$2"'
      fi
    fi
  fi
}
function ble/heap#.less { builtin eval -- "$__ble_less"; }

## @fn ble/heap#.push value
##   @param[in] value
##   @var[in] ${_ble_heap_vars[@]}
function ble/heap#.push {
  local __ble_i=$((__ble_len++)) __ble_j __ble_value=$1
  while ((__ble_i > 0)); do
    ((__ble_j=(__ble_i-1)/2))
    ble/heap#.less "$__ble_value" "${!__ble_jref}" || break
    builtin eval "$__ble_iref"'=${'"$__ble_jref"'}'
    __ble_i=$__ble_j
  done
  builtin eval "$__ble_iref"'=$__ble_value'
}

## @fn ble/heap#.replace i value
##   @param[in] i
##   @param[in] value
##   @var[in] ${_ble_heap_vars[@]}
function ble/heap#.replace {
  local __ble_i=$1 __ble_value=$2 __ble_j
  while (((__ble_j = 2 * __ble_i + 1) < __ble_len)); do
    ((__ble_j + 1 < __ble_len)) &&
      ble/heap#.less "${!__ble_kref}" "${!__ble_jref}" &&
      ((__ble_j++))
    ble/heap#.less "${!__ble_jref}" "$__ble_value" || break
    builtin eval "$__ble_iref"'=${'"$__ble_jref"'}'
    __ble_i=$__ble_j
  done
  builtin eval "$__ble_iref"'=$__ble_value'
}

## @fn ble/heap#.pop
##   @var[in] ${_ble_heap_vars[@]}
function ble/heap#.pop {
  ((__ble_len >= 1)) || return 1
  REPLY=${!__ble_0ref}

  local __ble_i=$((--__ble_len))
  local __ble_value=${!__ble_iref}
  builtin unset -v "$__ble_iref"
  ((__ble_len >= 1)) || return 0

  ble/heap#.replace 0 "$__ble_value"
}

## @fn ble/array#.heapify
##   @var[in] ${_ble_heap_vars[@]}
function ble/array#.heapify {
  local __ble_i
  for ((__ble_i = __ble_len / 2 - 1; __ble_i >= 0; __ble_i--)); do
    ble/heap#.replace "$__ble_i" "${!__ble_iref}"
  done
}

## @fn ble/heap#push name predicate_less value
##   @param[in] name
##   @param[in] predicate_less
##   @param[in] value
function ble/heap#push {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  ble/heap#.push "$3"
}

## @fn ble/heap#pop name predicate_less
##   @param[in] name
##   @param[in] predicate_less
function ble/heap#pop {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  ble/heap#.pop
}

## @fn ble/heap#replace-top name predicate_less value
##   @param[in] name
##   @param[in] predicate_less
##   @param[in] value
function ble/heap#replace-top {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  ble/heap#.replace 0 "$3"
}

## @fn ble/array#heapify name predicate_less
##   @param[in] name
##   @param[in] predicate_less
function ble/array#heapify {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  ble/array#.heapify
}

## @fn ble/array#is-heap name predicate_less
##   @param[in] name
##   @param[in] predicate_less
function ble/array#is-heap {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  local __ble_i __ble_j
  for ((__ble_i = __ble_len / 2 - 1; __ble_i >= 0; __ble_i--)); do
    ((__ble_j = 2 * __ble_i + 1))
    ble/heap#.less "${!__ble_jref}" "${!__ble_iref}" && return 1
    ((++__ble_j < __ble_len)) && ble/heap#.less "${!__ble_jref}" "${!__ble_iref}" && return 1
  done
  return 0
}

## @fn ble/array#.max count
##   @var[in] less __ble_len
function ble/array#.max {
  local __ble_request_count=$1
  ((__ble_request_count > __ble_len)) && __ble_request_count=$__ble_len
  if ((__ble_request_count <= 0)); then
    REPLY=()
    return 0
  fi

  if ((__ble_request_count == 1)); then
    REPLY=("${!__ble_0ref}")
    local __ble_i
    for ((__ble_i = 1; __ble_i < __ble_len; __ble_i++)); do
      ble/heap#.less "$REPLY" "${!__ble_iref}" && REPLY=${!__ble_iref}
    done
    return 0
  fi

  local __ble_sref=$__ble_iref
  local __ble_slen=$__ble_len

  local -a __ble_heap=()
  ble/heap#.initialize __ble_heap '' force

  local __ble_i __ble_len=0
  for ((__ble_i = 0; __ble_i < __ble_request_count; __ble_i++)); do
      ble/heap#.push "${!__ble_sref}"
  done
  for ((; __ble_i < __ble_slen; __ble_i++)); do
    local __ble_value=${!__ble_sref}
    ble/heap#.less "${!__ble_0ref}" "$__ble_value" &&
      ble/heap#.replace 0 "$__ble_value"
  done

  local -a __ble_out=()
  local __ble_i
  for ((__ble_i = __ble_request_count; --__ble_i >= 0; )); do
    ble/heap#.pop || break
    __ble_out[__ble_i]=$REPLY
  done
  REPLY=("${__ble_out[@]}")
}

## @fn ble/array#min name predicate_less [count]
##   @param[in] name
##   @param[in] predicate_less
##   @param[in] count
function ble/array#min {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2" reverse
  ble/array#.max "${3:-1}"
}

## @fn ble/array#max name predicate_less [count]
##   @param[in] name
##   @param[in] predicate_less
##   @param[in] count
function ble/array#max {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  ble/array#.max "${3:-1}"
}

#------------------------------------------------------------------------------

function ble/array#.min.i2 {
  local __ble_request_count=$1
  if ((__ble_len == 0 || __ble_request_count <= 0)); then
    REPLY=()
    return 0
  fi

  if ((__ble_request_count == 1)); then
    REPLY=("${!__ble_0ref}")
    local __ble_i
    for ((__ble_i = 1; __ble_i < __ble_len; __ble_i++)); do
      ble/heap#.less "${!__ble_iref}" "$REPLY" && REPLY=${!__ble_iref}
    done
    return 0
  fi

  ble/array#.heapify
  local -a __ble_out=()
  local __ble_i
  for ((__ble_i = 0; __ble_i < __ble_request_count; __ble_i++)); do
    ble/heap#.pop || break
    __ble_out[__ble_i]=$REPLY
  done
  REPLY=("${__ble_out[@]}")
}

## @fn ble/array#min.i2 name predicate_less [count]
##   @param[in] name
##   @param[in] predicate_less
##   @param[in] count
function ble/array#min.i2 {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2"
  ble/array#.min.i2 "${3:-1}"
}

## @fn ble/array#max.i2 name predicate_less [count]
##   @param[in] name
##   @param[in] predicate_less
##   @param[in] count
function ble/array#max.i2 {
  local "${_ble_heap_vars[@]}"
  ble/heap#.initialize "$1" "$2" reverse
  ble/array#.min.i2 "${3:-1}"
}

function ble/test:heap {
  local n REPLY data IFS=$' \t\n'
  for n in 0 1 2 3 4 5 10 20 40 100 1000 10000; do # 50000
    data=()
    local i
    for ((i = 0; i < n; i++)); do
      ble/array#push data "$RANDOM"
    done

    local TIMEFORMAT="$n %R"
    heap=("${data[@]}")
    time ble/array#heapify heap '(($1 < $2))'
    if ! ble/array#is-heap heap '(($1 < $2))'; then
      ble/util/print "error(n=$n): not heap"
      declare -p heap
    fi

    REPLY=($(printf '%s\n' "${data[@]}" | sort -n | head -n 10))
    local impl0_result="${REPLY[*]}"

    heap=("${data[@]}")
    time ble/array#min heap '(($1 < $2))' 10
    local impl1_result="${REPLY[*]}"

    heap=("${data[@]}")
    time ble/array#min.i2 heap '(($1 < $2))' 10
    local impl2_result="${REPLY[*]}"

    if [[ $impl1_result != "$impl0_result" || $impl2_result != "$impl0_result" ]]; then
      declare -p impl0_result impl1_result impl2_result
    fi
  done

  for n in 50000 100000; do
    data=()
    local i
    for ((i = 0; i < n; i++)); do
      ble/array#push data "$RANDOM"
    done

    local TIMEFORMAT="$n %R"

    REPLY=($(printf '%s\n' "${data[@]}" | sort -n | head -n 10))
    local impl0_result="${REPLY[*]}"

    heap=("${data[@]}")
    time ble/array#min heap '(($1 < $2))' 10
    local impl1_result="${REPLY[*]}"

    if [[ $impl1_result != "$impl0_result" ]]; then
      declare -p impl0_result impl1_result
    fi
  done
}
ble/test:heap
