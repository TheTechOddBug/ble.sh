#!/usr/bin/env bash

function alias-true-colors {
  local input=$1 min_count=$2 opts=$3
  
  local list=$(
    grep -nEo '#[a-f0-9]+\b' "$input" | sort -t : -k2 -k1n | awk -F : '
      !lineno[$2]{lineno[$2]=$1}
      {count[$2]++}
      END{
        for(k in count){print lineno[k], k, count[k]}
      }
    ' | sort -k3nr -k1n | awk -v min_count="$min_count" '$3 >= min_count {print "scheme" NR, $2}'
  )

  if [[ :$opts: == *:rewrite:* ]]; then
    sed -i.bk "$(awk '{print "s/" $2 "\\b/%" $1 "/g"}' <<< "$list")" "$input"
  fi

  awk '{print "ble/color/alias/set", $1, "'\''" $2 "'\''"}' <<< "$list"
}

# alias-true-colors catppuccin_mocha.bash    1 rewrite
# alias-true-colors catppuccin_mocha.bash.bk 1

alias-true-colors tokyo_night.bash 2 rewrite
