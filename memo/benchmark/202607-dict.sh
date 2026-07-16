#!/usr/bin/env bash

impl4v_use_varref=

declare -f ble-measure &>/dev/null || source src/benchmark.sh

function test_rand {
  local impl=$1 n=$2
  (
    #TIMEFORMAT='%R %U %S'
    TIMEFORMAT='%R'
    time {
      RANDOM=12345
      for ((i=0;i<n/2;i++)); do
        r=$RANDOM
        "$impl"#set "r$r" "$((r*(r+1)))"
      done
      r=$RANDOM
      "$impl"#set "r$r" "$((r*(r+1)))"
      needle=r$r
      answer=$((r*(r+1)))
      for ((i=0;i < (n-1)/2;i++)); do
        r=$RANDOM
        "$impl"#set "r$r" "$((r*(r+1)))"
      done
    }

    "$impl"#get "$needle"
    [[ $REPLY == "$answer" ]] || {
      echo wrong
      declare -p REPLY answer "${!impl4a_@}"
    }

    # Note: RANDOM が衝突すると普通に要素数が減る。
    #
    # "$impl"#keys
    # ((${#REPLY[@]} == n)) || {
    #   echo "keys: count=${#REPLY[@]}; wrong"
    #   ((${#REPLY[@]} < 100)) && declare -p REPLY
    # }

    if ((n <= 100)); then
      ble-measure -c10 "$impl#get $needle"
    else
      ble-measure "$impl#get $needle"
    fi
  )
}

function test_seq {
  local impl=$1 n=$2
  (
    TIMEFORMAT='%R'
    time {
      for ((i=0;i<n/2;i++)); do
        r=$i
        "$impl"#set "r$r" "$((r*(r+1)))"
      done
      r=$((n/2))
      "$impl"#set "r$r" "$((r*(r+1)))"
      needle=r$r
      answer=$((r*(r+1)))
      for ((i=0;i < (n-1)/2;i++)); do
        r=$((n/2+1+i))
        "$impl"#set "r$r" "$((r*(r+1)))"
      done
    }

    "$impl"#get "$needle"
    [[ $REPLY == "$answer" ]] || echo wrong

    "$impl"#keys
    ((${#REPLY[@]} == n)) || {
      echo "keys: count=${#REPLY[@]}; wrong"
      ((${#REPLY[@]} < 100)) && declare -p REPLY
    }

    ble-measure "$impl#get $needle"
  )
}


if ((BASH_VERSINFO[0] >= 4)); then
  declare -gA impl0=()

  function impl0#get {
    REPLY=${impl0[$1]}
  }
  function impl0#set {
    impl0[$1]=$2
  }
  function impl0#keys {
    REPLY=("${!impl0[@]}")
  }
fi

#------------------------------------------------------------------------------
# 現行の方式 (glob による線形探索)

impl1_keys=:
impl1_vals=()

function impl1#locate {
  local tmp=${impl1_keys%%:"$1":*}
  ((${#tmp} != ${#impl1_keys})) || return 1
  tmp=${tmp//[!:]}
  REPLY=${#tmp}
}

function impl1#set {
  local REPLY
  if impl1#locate "$1"; then
    impl1_vals[REPLY]=$2
  else
    impl1_keys=$impl1_keys$1:
    impl1_vals[${#impl1_vals[@]}]=$2
  fi
}

function impl1#get {
  impl1#locate "$1" &&
    REPLY=${impl1_vals[REPLY]}
}

function impl1#keys {
  local IFS=:
  REPLY=($impl1_keys)
}

# (
#   impl1#set banana yellow
#   impl1#set apple orange
#   impl1#set flower green
#   impl1#get apple; echo "$REPLY"
#   ble-measure 'impl1#get apple'
# )

#------------------------------------------------------------------------------
# 単純な配列

impl2_keys=()
impl2_vals=()

function impl2#locate {
  local i n=${#impl2_keys[@]}
  for ((i=0;i<n;i++)); do
    [[ ${impl2_keys[i]} == "$1" ]] && break
  done
  ((i < n)) && REPLY=$i
}

function impl2#set {
  if impl2#locate "$1"; then
    impl2_vals[REPLY]=$2
  else
    REPLY=${#impl2_keys[@]}
    impl2_keys[REPLY]=$1
    impl2_vals[REPLY]=$2
  fi
}

function impl2#get {
  impl2#locate "$1" && REPLY=${impl2_vals[REPLY]}
}

function impl2#keys {
  REPLY=("${impl2_keys[@]}")
}

#------------------------------------------------------------------------------
# 単純な配列 (impl2) をくっつけたもの

impl3_kv=()

function impl3#locate {
  local i n=${#impl3_kv[@]}
  for ((i=0;i<n;i+=2)); do
    [[ ${impl3_kv[i]} == "$1" ]] && break
  done
  ((i < n)) && REPLY=$i
}

function impl3#set {
  if impl3#locate "$1"; then
    impl3_kv[REPLY+1]=$2
  else
    REPLY=${#impl3_kv[@]}
    impl3_kv[REPLY]=$1
    impl3_kv[REPLY+1]=$2
  fi
}

function impl3#get {
  impl3#locate "$1" && REPLY=${impl3_kv[REPLY+1]}
}

function impl3#keys {
  REPLY=()
  local i n=${#impl3_kv[@]}
  for ((i = 0; i < n; i += 2)); do
    REPLY[i/2]=${impl3_kv[i]}
  done
}

#------------------------------------------------------------------------------
# AVL tree. I initially tried to produce the code with Google AI, but the code
# didn't work at all. I decided to implement it myself.

function impl4#clear {
  impl4_keys=()
  impl4_vals=()
  impl4_lptrs=()
  impl4_rptrs=()
  impl4_deps=()
  impl4_free=-1
  impl4_root=-1
}

function impl4#.alloc {
  if ((impl4_free >= 0)); then
    REPLY=$impl4_free
    impl4_free=${impl4_lptrs[REPLY]}
  else
    REPLY=${#impl4_keys[@]}
  fi
  impl4_keys[REPLY]=$1
  impl4_vals[REPLY]=$2
  impl4_lptrs[REPLY]=-1
  impl4_rptrs[REPLY]=-1
  impl4_deps[REPLY]=1
}
function impl4#.free {
  impl4_lptrs[$1]=$impl4_free
  impl4_free=$1
}

function impl4#.depth {
  local i=$1
  if ((i < 0)); then
    REPLY=0
  else
    REPLY=${impl4_deps[i]}
  fi
}
function impl4#.depth.update {
  local i=$1 REPLY
  impl4#.depth "${impl4_lptrs[i]}"; local ldep=$REPLY
  impl4#.depth "${impl4_rptrs[i]}"; local rdep=$REPLY
  impl4_deps[i]=$(((ldep>=rdep?ldep:rdep)+1))
}
## @fn impl4#.depth.ror i
##   Rotate right as ((LL l LR) i R) → (LL l *(*LR i R))
##   @var[out] REPLY - returns the new root.
function impl4#.depth.ror {
  local i=$1
  local l=${impl4_lptrs[i]}
  impl4_lptrs[i]=${impl4_rptrs[l]}
  impl4_rptrs[l]=$i
  impl4#.depth.update "$i"
  impl4#.depth.update "$l"
  REPLY=$l
}
## @fn impl4#.depth.ror i
##   Rotate left as (L i (RL r RR)) → (*(L i *RL) r RR)
##   @var[out] REPLY - returns the new root.
function impl4#.depth.rol {
  local i=$1
  local r=${impl4_rptrs[i]}
  impl4_rptrs[i]=${impl4_lptrs[r]}
  impl4_lptrs[r]=$i
  impl4#.depth.update "$i"
  impl4#.depth.update "$r"
  REPLY=$r
}
## @fn impl4#.path.rebalance i
##   @param[in] i
##     The axis of the rebalancing.
##   @var[in] d path
##     The current depth and the array of path.
##   @exit 0 if the height of the present depth is unchanged, or otherwise 1.
function impl4#.path.rebalance {
  local i=$1 REPLY
  local idep=${impl4_deps[i]}
  local l=${impl4_lptrs[i]}; impl4#.depth "$l"; local ldep=$REPLY
  local r=${impl4_rptrs[i]}; impl4#.depth "$r"; local rdep=$REPLY
  if ((ldep >= rdep + 2)); then
    impl4#.depth "${impl4_lptrs[l]}"; local lldep=$REPLY
    impl4#.depth "${impl4_rptrs[l]}"; local lrdep=$REPLY
    if ((lldep<lrdep)); then
      impl4#.depth.rol "$l"
      impl4_lptrs[i]=$REPLY
    fi
    impl4#.depth.ror "$i"
  elif ((rdep >= ldep + 2)); then
    impl4#.depth "${impl4_lptrs[r]}"; local rldep=$REPLY
    impl4#.depth "${impl4_rptrs[r]}"; local rrdep=$REPLY
    if ((rldep>rrdep)); then
      impl4#.depth.ror "$r"
      impl4_rptrs[i]=$REPLY
    fi
    impl4#.depth.rol "$i"
  else
    impl4#.depth.update "$i"
    ((impl4_deps[i] == idep))
    return "$?"
  fi

  impl4#.path.reconnect-parent "$REPLY"

  ((impl4_deps[REPLY] == idep))
}

function impl4#.path.reconnect-parent {
  if ((d == 0)); then
    impl4_root=$1
  elif local p=${path[d-1]}; ((impl4_lptrs[p] == path[d])); then
    impl4_lptrs[p]=$1
  else
    impl4_rptrs[p]=$1
  fi
}

function impl4#.locate {
  local i=$impl4_root
  while ((i >= 0)); do
    local k=${impl4_keys[i]}
    if [[ $1 == "$k" ]]; then
      REPLY=$i
      return 0
    elif [[ $1 < "$k" ]]; then
      i=${impl4_lptrs[i]}
    else
      i=${impl4_rptrs[i]}
    fi
  done
  return 1
}

function impl4#get {
  impl4#.locate "$1" && REPLY=${impl4_vals[REPLY]}
}

function impl4#has {
  local REPLY
  impl4#.locate "$1"
}

function impl4#set {
  local REPLY i=$impl4_root
  if ((i < 0)); then
    impl4#.alloc "$1" "$2"
    impl4_root=$REPLY
    return 0
  fi

  local path d
  for ((d = 0; ; d++)); do
    path[d]=$i
    local b=$i k=${impl4_keys[i]}
    if [[ $1 == "$k" ]]; then
      impl4_vals[i]=$2
      return 0
    elif [[ $1 < "$k" ]]; then
      i=${impl4_lptrs[i]}
      if ((i < 0)); then
        impl4#.alloc "$1" "$2"
        impl4_lptrs[path[d]]=$REPLY
        break
      fi
    else
      i=${impl4_rptrs[i]}
      if ((i < 0)); then
        impl4#.alloc "$1" "$2"
        impl4_rptrs[path[d]]=$REPLY
        break
      fi
    fi
  done

  while ((--d >= 0)); do
    impl4#.path.rebalance "${path[d]}" && break
  done
}

function impl4#unset {
  local i=$impl4_root REPLY
  local d path target=
  for ((d = 0; i >= 0; d++)); do
    path[d]=$i
    local b=$i k=${impl4_keys[i]}
    if [[ $1 == "$k" ]]; then
      target=$i

      local l=${impl4_lptrs[i]}; impl4#.depth "$l"; local ldep=$REPLY
      local r=${impl4_rptrs[i]}; impl4#.depth "$r"; local rdep=$REPLY
      if ((ldep >= rdep)); then
        i=$l
      else
        i=$r
      fi
    elif [[ $1 < "$k" ]]; then
      i=${impl4_lptrs[i]}
    else
      i=${impl4_rptrs[i]}
    fi
  done

  # If the target kvpair to remove is not found, we just return.
  [[ $target ]] || return 1

  # Move the deepest adjacent kvpair at the "i" cell to the "target" cell.
  if ((target != (i = path[--d]))); then
    impl4_keys[target]=${impl4_keys[i]}
    impl4_vals[target]=${impl4_vals[i]}
  fi

  # Remove the "i" cell.  Note: since the loop stops when finding -1 on either
  # lptrs or rptrs, there is only one child at most.  We reconnect the child to
  # the parent.
  if ((impl4_lptrs[i] != -1)); then
    impl4#.path.reconnect-parent "${impl4_lptrs[i]}"
  else
    impl4#.path.reconnect-parent "${impl4_rptrs[i]}"
  fi
  impl4#.free "$i"

  # Rebalance and recalculate the depth
  while ((--d >= 0)); do
    impl4#.path.rebalance "${path[d]}" && break
  done
}

## @fn impl4#.path.next
##   @var[ref] path d
##   @var[out] REPLY
function impl4#.path.next {
  local i=$((d == 0 ? impl4_root : impl4_rptrs[path[d >= 1 ? d - 1 : 0]]))
  if ((i >= 0)); then
    while ((path[d++] = i, (i = impl4_lptrs[i]) >= 0)); do
      continue
    done
  else
    while ((--d >= 1)) && ((impl4_rptrs[path[d-1]] == path[d])); do
      continue
    done
  fi
  ((d >= 1)) || return 1
  REPLY=${path[d-1]}
}

function impl4#keys {
  REPLY=()
  local d=0 path i=0
  while impl4#.path.next; do
    REPLY[i++]=${impl4_keys[REPLY]]}
  done
}

impl4#clear

(
  impl4#set "banana" "黄"
  impl4#set "apple"  "赤"
  impl4#set "cherry" "桜"

  # テスト2: データの取得
  test_name=検索テスト
  impl4#get "apple";  [[ $REPLY == '赤' ]] || echo "fail($test_name): apple  -> $REPLY (期待値: 赤)"
  impl4#get "banana"; [[ $REPLY == '黄' ]] || echo "fail($test_name): banana -> $REPLY (期待値: 黄)"
  impl4#get "cherry"; [[ $REPLY == '桜' ]] || echo "fail($test_name): cherry -> $REPLY (期待値: 桜)"

  # テスト3: 値の上書き
  test_name=上書きテスト
  impl4#set "banana" "完熟黄"
  impl4#get "banana"; [[ $REPLY == '完熟黄' ]] || echo "fail($test_name): banana -> $REPLY (期待値: 完熟黄)"

  # テスト4: 存在しないキーの検索
  test_name=存在しないキー
  if impl4#get "durian"; then
    echo "fail($test_name): durian -> $REPLY"
  fi

  # impl4#keys
  # declare -p REPLY

  # # デバッグ用: 内部配列のダンプ
  # echo "--- 内部配列の状態 ---"
  # for ((idx=0; idx<${#impl4_keys[@]}; idx++)); do
  #   echo "Bucket $idx: Key=[${impl4_keys[idx]}] Val=[${impl4_vals[idx]}] L=${impl4_lptrs[idx]} R=${impl4_rptrs[idx]}"
  # done
  # echo "Root Index: $impl4_root"
)

# AI-generated test cases for impl4#unset

function impl4#.check-tree {
  local test_name="$1"
  local expected_count="$2"
  local idx count=0 error=0

  # 1. 件数とポインタの整合性チェック
  local path d=0 REPLY
  while impl4#.path.next; do
    local idx=$REPLY
    local k="${impl4_keys[idx]}"
    # free されていない有効なノードのみカウント
    if [[ -n "$k" ]]; then
      ((count++))

      # 左ポインタの検証
      local l=${impl4_lptrs[idx]}
      if ((l >= 0)); then
        if [[ ! "${impl4_keys[l]}" < "$k" ]]; then
          echo "  [FAIL] ノード[$k]の左子[${impl4_keys[l]}]の順序が不正です。"
          error=1
        fi
      fi

      # 右ポインタの検証
      local r=${impl4_rptrs[idx]}
      if ((r >= 0)); then
        if [[ ! "$k" < "${impl4_keys[r]}" ]]; then
          echo "  [FAIL] ノード[$k]の右子[${impl4_keys[r]}]の順序が不正です。"
          error=1
        fi
      fi
    fi
  done

  # 2. 結果出力
  if ((count != expected_count)); then
    echo "  [FAIL] 要素数が一致しません。期待値: $expected_count, 実際の値: $count"
    error=1
  fi

  if ((error == 0)); then
    echo "  [OK] $test_name (要素数: $count)"
  else
    echo "  [CRITICAL] $test_name で木構造が破壊されました。"
    exit 1
  fi
}

function impl4v#.key {
  builtin eval 'REPLY=${'"$dict"'_keys[$1]}'
}
function impl4v#.lptr {
  builtin eval 'REPLY=${'"$dict"'_lptrs[$1]}'
}
function impl4v#.rptr {
  builtin eval 'REPLY=${'"$dict"'_rptrs[$1]}'
}
function impl4v#.check-tree {
  local test_name=$1
  local expected_count=$2
  local i count=0 error=0

  # 1. 件数とポインタの整合性チェック
  local path d=0 REPLY
  while impl4v#.path.next; do
    local i=$REPLY
    impl4v#.key "$i"; local k=$REPLY
    # free されていない有効なノードのみカウント
    if [[ -n "$k" ]]; then
      ((count++))

      # 左ポインタの検証
      impl4v#.lptr "$i"; local l=$REPLY
      if ((l >= 0)); then
        impl4v#.key "$l"
        if [[ ! "$REPLY" < "$k" ]]; then
          echo "  [FAIL] ノード[$k]の左子[$REPLY]の順序が不正です。"
          error=1
        fi
      fi

      # 右ポインタの検証
      impl4v#.rptr "$i"; local r=$REPLY
      if ((r >= 0)); then
        impl4v#.key "$r"
        if [[ ! "$k" < "$REPLY" ]]; then
          echo "  [FAIL] ノード[$k]の右子[$REPLY]の順序が不正です。"
          error=1
        fi
      fi
    fi
  done

  # 2. 結果出力
  if ((count != expected_count)); then
    echo "  [FAIL] 要素数が一致しません。期待値: $expected_count, 実際の値: $count"
    error=1
  fi

  if ((error == 0)); then
    echo "  [OK] $test_name (要素数: $count)"
  else
    echo "  [CRITICAL] $test_name で木構造が破壊されました。"
    exit 1
  fi
}

function impl/check-unset {
  local impl=$1
  echo "=========================================="
  echo "  impl4#unset 徹底検証テストを開始します"
  echo "=========================================="

  echo "【ケース1】基本操作と存在しないキーの削除"
  "$impl#clear"
  "$impl#set" "M" "13"
  "$impl#set" "G" "7"
  "$impl#set" "R" "18"

  # 存在しないキーの削除で正しく 1 (偽) が返るか
  if "$impl#unset" "X"; then
    echo "  [FAIL] 存在しないキー 'X' の削除が成功してしまいました。"
  else
    echo "  [OK] 存在しないキーの削除(正常に失敗)"
  fi
  "$impl#.check-tree" "初期状態確認" 3

  echo "【ケース2】葉ノード（子が0個）の削除"
  # "G" を削除 (M の左の葉)
  "$impl#unset" "G"
  if "$impl#has" "G"; then
    echo "  [FAIL] 'G' がまだ残っています。"
  else
    "$impl#.check-tree" "葉ノード削除後の構造" 2
  fi

  echo "【ケース3】子が1個だけあるノードの削除（孫の救出）"
  "$impl#clear"
  "$impl#set" "M" "13"
  "$impl#set" "G" "7"
  "$impl#set" "D" "4" # M -> G -> D という左一本道の偏り (通常ならAVLでバランスされますが今回は実験用)
  # AVL木が効く前の初期状態として、G は子を1つ(D)持っている。Gを消してDがMに直結するか
  "$impl#unset" "G"
  "$impl#get" "D" >/dev/null
  if (( $? == 0 )) && [[ $REPLY == "4" ]]; then
    "$impl#.check-tree" "子が1個のノード削除(孫の直結)" 2
  else
    echo "  [FAIL] 子が1個のノード削除で孫ノード 'D' を見失いました。REPLY=$REPLY"
  fi

  echo "【ケース4】子が2つあるノードの削除（後継ノード自動誘導の検証）"
  "$impl#clear"
  # 以下の構成を作る (Oを消した時に、右サブツリーの最小値 'R' が上に上がるか)
  #        O
  #       / \
  #      G   T
  #         / \
  #        R   V
  "$impl#set" "O" "15"
  "$impl#set" "G" "7"
  "$impl#set" "T" "20"
  "$impl#set" "R" "18"
  "$impl#set" "V" "22"

  "$impl#unset" "O" # 根ノード(子が2つ)を削除
  if "$impl#has" "O"; then
    echo "  [FAIL] 子が2つのノード 'O' の削除に失敗しました。"
  else
    "$impl#get" "G"; local vg=$REPLY
    "$impl#get" "T"; local vt=$REPLY
    if [[ $vg == "7" && $vt == "20" ]]; then
      "$impl#.check-tree" "子が2つのノード削除(後継ノード引き上げ)" 4
    else
      echo "  [FAIL] 周辺のデータ(GまたはT)が書き換わってしまいました。"
    fi
  fi

  echo "【ケース5】削除によって引き起こされる「単一回転・二重回転」の自動平衡化検証"
  "$impl#clear"

  # 特殊文字（グロブや改行）を含む意地悪なデータセット
  # 辞書順で綺麗に並んだデータを使って、削除時に回転を強制発生させる
  "$impl#set" "1_apple"  "A"
  "$impl#set" "2_banana" "B"
  "$impl#set" "3_cherry" "C"
  "$impl#set" "4_*"      "D" # グロブ文字
  "$impl#set" "5_?"      "E" # グロブ文字
  "$impl#set" "6_line
  feed" "F"                 # 改行入りキー

  "$impl#.check-tree" "特殊文字データ投入完了" 6

  # 末尾を消すことで、上の階層でバランス崩壊を起こさせて回転をトリガーする
  "$impl#unset" "6_line
  feed"
  "$impl#.check-tree" "削除リバランス1" 5

  "$impl#unset" "1_apple"
  "$impl#.check-tree" "削除リバランス2" 4

  echo "【ケース6】大量の追加・削除に対するフリーリスト（alloc/free）の耐久テスト"
  "$impl#clear"

  # 100要素を投入
  for ((idx=0; idx<100; idx++)); do
    # 3桁のゼロパディングで辞書順を維持したキーを生成
    key=$(printf "k_%03d" $idx)
    "$impl#set" "$key" "v_$idx"
  done
  "$impl#.check-tree" "大量投入後" 100

  # 偶数番目をすべて削除
  for ((idx=0; idx<100; idx+=2)); do
    key=$(printf "k_%03d" $idx)
    "$impl#unset" "$key"
  done
  "$impl#.check-tree" "半分間引き削除後" 50

  # 奇数番目がちゃんと残っているか、かつ取得できるかチェック
  all_ok=1
  for ((idx=1; idx<100; idx+=2)); do
    key=$(printf "k_%03d" $idx)
    if ! "$impl#get" "$key" >/dev/null; then
      all_ok=0
    fi
  done

  if ((all_ok == 1)); then
    echo "  [OK] 削除されなかった残存データの整合性確認"
  else
    echo "  [FAIL] 削除の過程で無関係なデータが巻き添えで消えました。"
  fi

  echo "=========================================="
  echo "  すべてのテストケースが完了しました！"
  echo "=========================================="
}

#------------------------------------------------------------------------------
# impl4v: the version with the dictionary name

function impl4v#clear {
  local dict=$1 script='
    NAME_keys=()
    NAME_vals=()
    NAME_lptrs=()
    NAME_rptrs=()
    NAME_deps=()
    NAME_free=-1
    NAME_root=-1
  '
  builtin eval -- "${script//NAME/$dict}"
}

function impl4v#.alloc {
  if ((${dict}_free >= 0)); then
    REPLY=$((${dict}_free))
    ((${dict}_free=${dict}_lptrs[REPLY]))
  else
    builtin eval 'REPLY=${#'"$dict"'_keys[@]}'
  fi
  builtin eval "$dict"'_keys[REPLY]=$1'
  builtin eval "$dict"'_vals[REPLY]=$2'
  ((${dict}_lptrs[REPLY]=${dict}_rptrs[REPLY]=-1,${dict}_deps[REPLY]=1))
}
function impl4v#.free {
  ((${dict}_lptrs[$1]=${dict}_free,${dict}_free=$1))
}

function impl4v#.depth {
  local i=$1
  if ((i < 0)); then
    REPLY=0
  else
    REPLY=$((${dict}_deps[i]))
  fi
}
function impl4v#.depth.update {
  local i=$1 REPLY
  impl4v#.depth "$((${dict}_lptrs[i]))"; local ldep=$REPLY
  impl4v#.depth "$((${dict}_rptrs[i]))"; local rdep=$REPLY
  ((${dict}_deps[i]=(ldep>=rdep?ldep:rdep)+1))
}
## @fn impl4v#.depth.ror i
##   Rotate right as ((LL l LR) i R) → (LL l *(*LR i R))
##   @var[out] REPLY - returns the new root.
function impl4v#.depth.ror {
  local i=$1
  local l=$((${dict}_lptrs[i]))
  ((${dict}_lptrs[i]=${dict}_rptrs[l],${dict}_rptrs[l]=i))
  impl4v#.depth.update "$i"
  impl4v#.depth.update "$l"
  REPLY=$l
}
## @fn impl4v#.depth.ror i
##   Rotate left as (L i (RL r RR)) → (*(L i *RL) r RR)
##   @var[out] REPLY - returns the new root.
function impl4v#.depth.rol {
  local i=$1
  local r=$((${dict}_rptrs[i]))
  ((${dict}_rptrs[i]=${dict}_lptrs[r],${dict}_lptrs[r]=i))
  impl4v#.depth.update "$i"
  impl4v#.depth.update "$r"
  REPLY=$r
}
## @fn impl4v#.path.rebalance i
##   @param[in] i
##     The axis of the rebalancing.
##   @var[in] d path
##     The current depth and the array of path.
##   @exit 0 if the height of the present depth is unchanged, or otherwise 1.
function impl4v#.path.rebalance {
  local i=$1 REPLY
  local idep=$((${dict}_deps[i]))
  local l=$((${dict}_lptrs[i])); impl4v#.depth "$l"; local ldep=$REPLY
  local r=$((${dict}_rptrs[i])); impl4v#.depth "$r"; local rdep=$REPLY
  if ((ldep >= rdep + 2)); then
    impl4v#.depth "$((${dict}_lptrs[l]))"; local lldep=$REPLY
    impl4v#.depth "$((${dict}_rptrs[l]))"; local lrdep=$REPLY
    if ((lldep<lrdep)); then
      impl4v#.depth.rol "$l"
      ((${dict}_lptrs[i]=REPLY))
    fi
    impl4v#.depth.ror "$i"
  elif ((rdep >= ldep + 2)); then
    impl4v#.depth "$((${dict}_lptrs[r]))"; local rldep=$REPLY
    impl4v#.depth "$((${dict}_rptrs[r]))"; local rrdep=$REPLY
    if ((rldep>rrdep)); then
      impl4v#.depth.ror "$r"
      ((${dict}_rptrs[i]=REPLY))
    fi
    impl4v#.depth.rol "$i"
  else
    impl4v#.depth.update "$i"
    ((${dict}_deps[i] == idep))
    return "$?"
  fi

  impl4v#.path.reconnect-parent "$REPLY"

  ((${dict}_deps[REPLY] == idep))
}

function impl4v#.path.reconnect-parent {
  local i=$1
  if ((d == 0)); then
    ((${dict}_root=i))
  elif local p=${path[d-1]}; ((${dict}_lptrs[p] == path[d])); then
    ((${dict}_lptrs[p]=i))
  else
    ((${dict}_rptrs[p]=i))
  fi
}

function impl4v#.locate {
  local i=$((${dict}_root)) kref=${dict}_keys[i]
  while ((i >= 0)); do
    local k=${!kref}
    if [[ $1 == "$k" ]]; then
      REPLY=$i
      return 0
    elif [[ $1 < "$k" ]]; then
      i=$((${dict}_lptrs[i]))
    else
      i=$((${dict}_rptrs[i]))
    fi
  done
  return 1
}

function impl4v#get {
  local dict=$1
  REPLY=
  impl4v#.locate "$2" && REPLY=${dict}_vals[$REPLY] REPLY=${!REPLY}
}

function impl4v#has {
  local dict=$1 REPLY
  impl4v#.locate "$2"
}

function impl4v#set {
  local dict=$1
  local REPLY i=$((${dict}_root))
  if ((i < 0)); then
    impl4v#.alloc "$2" "$3"
    ((${dict}_root=REPLY))
    return 0
  fi

  local path d kref=${dict}_keys[i]
  for ((d = 0; ; d++)); do
    path[d]=$i
    local b=$i k=${!kref}
    if [[ $2 == "$k" ]]; then
      builtin eval "$dict"'_vals[i]=$3'
      return 0
    elif [[ $2 < "$k" ]]; then
      i=$((${dict}_lptrs[i]))
      if ((i < 0)); then
        impl4v#.alloc "$2" "$3"
        ((${dict}_lptrs[path[d]]=REPLY))
        break
      fi
    else
      i=$((${dict}_rptrs[i]))
      if ((i < 0)); then
        impl4v#.alloc "$2" "$3"
        ((${dict}_rptrs[path[d]]=REPLY))
        break
      fi
    fi
  done

  while ((--d >= 0)); do
    impl4v#.path.rebalance "${path[d]}" && break
  done
}

function impl4v#unset {
  local dict=$1 REPLY
  local i=$((${dict}_root)) kref=${dict}_keys[i]
  local d path target=
  for ((d = 0; i >= 0; d++)); do
    path[d]=$i
    local b=$i k=${!kref}
    if [[ $2 == "$k" ]]; then
      target=$i

      local l=$((${dict}_lptrs[i])); impl4v#.depth "$l"; local ldep=$REPLY
      local r=$((${dict}_rptrs[i])); impl4v#.depth "$r"; local rdep=$REPLY
      if ((ldep >= rdep)); then
        i=$l
      else
        i=$r
      fi
    elif [[ $2 < "$k" ]]; then
      i=$((${dict}_lptrs[i]))
    else
      i=$((${dict}_rptrs[i]))
    fi
  done

  # If the target kvpair to remove is not found, we just return.
  [[ $target ]] || return 1

  # Move the deepest adjacent kvpair at the "i" cell to the "target" cell.
  if ((target != (i = path[--d]))); then
    builtin eval "$dict"'_keys[target]=${'"$dict"'_keys[i]}'
    builtin eval "$dict"'_vals[target]=${'"$dict"'_vals[i]}'
  fi

  # Remove the "i" cell.  Note: since the loop stops when finding -1 on either
  # lptrs or rptrs, there is only one child at most.  We reconnect the child to
  # the parent.
  if ((${dict}_lptrs[i] != -1)); then
    impl4v#.path.reconnect-parent "$((${dict}_lptrs[i]))"
  else
    impl4v#.path.reconnect-parent "$((${dict}_rptrs[i]))"
  fi
  impl4v#.free "$i"

  # Rebalance and recalculate the depth
  while ((--d >= 0)); do
    impl4v#.path.rebalance "${path[d]}" && break
  done
}

## @fn impl4v#.path.next
##   @var[ref] path d
##   @var[out] REPLY
function impl4v#.path.next {
  local i=$((d == 0 ? ${dict}_root : ${dict}_rptrs[path[d >= 1 ? d - 1 : 0]]))
  if ((i >= 0)); then
    while ((path[d++] = i, (i = ${dict}_lptrs[i]) >= 0)); do
      continue
    done
  else
    while ((--d >= 1)) && ((${dict}_rptrs[path[d-1]] == path[d])); do
      continue
    done
  fi
  ((d >= 1)) || return 1
  REPLY=${path[d-1]}
}

function impl4v#keys {
  local dict=$1
  REPLY=()
  local d=0 path i=0 kref=${dict}_keys[REPLY]
  while impl4v#.path.next; do
    REPLY[i++]=${!kref}
  done
}

# adapters

function impl4a#clear {
  impl4v#clear impl4a
}
function impl4a#set {
  impl4v#set impl4a "$1" "$2"
}
function impl4a#get {
  impl4v#get impl4a "$1"
}
function impl4a#has {
  impl4v#has impl4a "$1"
}
function impl4a#unset {
  impl4v#unset impl4a "$1"
}
function impl4a#keys {
  impl4v#keys impl4a
}
function impl4a#.check-tree {
  local dict=impl4a
  impl4v#.check-tree "$@"
}
impl4a#clear

#------------------------------------------------------------------------------
# impl4v: Even another version using ${!ref}.  This slightly improves the
# performance, but it's not so useful because it can be used only when reading
# the value.  We still need to rely on eval or arithmetic evaluation for
# assigning values.

if [[ $impl4v_use_varref ]]; then
  function impl4v#.depth {
    local i=$1
    if ((i < 0)); then
      REPLY=0
    else
      REPLY=${!dref}
    fi
  }
  function impl4v#.depth.update {
    local i=$1 REPLY
    impl4v#.depth "${!lref}"; local ldep=$REPLY
    impl4v#.depth "${!rref}"; local rdep=$REPLY
    ((${dict}_deps[i]=(ldep>=rdep?ldep:rdep)+1))
  }
  ## @fn impl4v#.depth.ror i
  ##   Rotate right as ((LL l LR) i R) → (LL l *(*LR i R))
  ##   @var[out] REPLY - returns the new root.
  function impl4v#.depth.ror {
    local i=$1
    local l=${!lref}
    ((${dict}_lptrs[i]=${dict}_rptrs[l],${dict}_rptrs[l]=i))
    impl4v#.depth.update "$i"
    impl4v#.depth.update "$l"
    REPLY=$l
  }
  ## @fn impl4v#.depth.ror i
  ##   Rotate left as (L i (RL r RR)) → (*(L i *RL) r RR)
  ##   @var[out] REPLY - returns the new root.
  function impl4v#.depth.rol {
    local i=$1
    local r=${!rref}
    ((${dict}_rptrs[i]=${dict}_lptrs[r],${dict}_lptrs[r]=i))
    impl4v#.depth.update "$i"
    impl4v#.depth.update "$r"
    REPLY=$r
  }
  ## @fn impl4v#.path.rebalance i
  ##   @param[in] i
  ##     The axis of the rebalancing.
  ##   @var[in] d path
  ##     The current depth and the array of path.
  ##   @exit 0 if the height of the present depth is unchanged, or otherwise 1.
  function impl4v#.path.rebalance {
    local i=$1 REPLY
    local idep=${!dref}
    local l=${!lref}; impl4v#.depth "$l"; local ldep=$REPLY
    local r=${!rref}; impl4v#.depth "$r"; local rdep=$REPLY
    if ((ldep >= rdep + 2)); then
      impl4v#.depth "$((${dict}_lptrs[l]))"; local lldep=$REPLY
      impl4v#.depth "$((${dict}_rptrs[l]))"; local lrdep=$REPLY
      if ((lldep<lrdep)); then
        impl4v#.depth.rol "$l"
        ((${dict}_lptrs[i]=REPLY))
      fi
      impl4v#.depth.ror "$i"
    elif ((rdep >= ldep + 2)); then
      impl4v#.depth "$((${dict}_lptrs[r]))"; local rldep=$REPLY
      impl4v#.depth "$((${dict}_rptrs[r]))"; local rrdep=$REPLY
      if ((rldep>rrdep)); then
        impl4v#.depth.ror "$r"
        ((${dict}_rptrs[i]=REPLY))
      fi
      impl4v#.depth.rol "$i"
    else
      impl4v#.depth.update "$i"
      ((${dict}_deps[i] == idep))
      return "$?"
    fi

    impl4v#.path.reconnect-parent "$REPLY"

    ((${dict}_deps[REPLY] == idep))
  }

  function impl4v#.locate {
    local root=${dict}_root
    local kref=${dict}_keys[i]
    local lref=${dict}_lptrs[i]
    local rref=${dict}_rptrs[i]
    local i=${!root}
    while ((i >= 0)); do
      local k=${!kref}
      if [[ $1 == "$k" ]]; then
        REPLY=$i
        return 0
      elif [[ $1 < "$k" ]]; then
        i=${!lref}
      else
        i=${!rref}
      fi
    done
    return 1
  }

  function impl4v#set {
    local dict=$1
    local lref=${dict}_lptrs[i]
    local rref=${dict}_rptrs[i]
    local dref=${dict}_deps[i]
    local kref=${dict}_keys[i]
    local vref=${dict}_vals[i]
    local root=${dict}_root
    local free=${dict}_free

    local REPLY i=${!root}
    if ((i < 0)); then
      impl4v#.alloc "$2" "$3"
      (($root=REPLY))
      return 0
    fi

    local path d
    for ((d = 0; ; d++)); do
      path[d]=$i
      local b=$i k=${!kref}
      if [[ $2 == "$k" ]]; then
        builtin eval -- "$dict"'_vals[i]=$3'
        return 0
      elif [[ $2 < "$k" ]]; then
        i=${!lref}
        if ((i < 0)); then
          impl4v#.alloc "$2" "$3"
          ((${dict}_lptrs[path[d]]=REPLY))
          break
        fi
      else
        i=${!rref}
        if ((i < 0)); then
          impl4v#.alloc "$2" "$3"
          ((${dict}_rptrs[path[d]]=REPLY))
          break
        fi
      fi
    done

    while ((--d >= 0)); do
      impl4v#.path.rebalance "${path[d]}" && break
    done
  }

  function impl4v#unset {
    local dict=$1
    local lref=${dict}_lptrs[i]
    local rref=${dict}_rptrs[i]
    local dref=${dict}_deps[i]
    local kref=${dict}_keys[i]
    local vref=${dict}_vals[i]
    local root=${dict}_root
    local free=${dict}_free

    local REPLY i=${!root}
    local d path target=
    for ((d = 0; i >= 0; d++)); do
      path[d]=$i
      local b=$i k=${!kref}
      if [[ $2 == "$k" ]]; then
        target=$i

        local l=${!lref}; impl4v#.depth "$l"; local ldep=$REPLY
        local r=${!rref}; impl4v#.depth "$r"; local rdep=$REPLY
        if ((ldep >= rdep)); then
          i=$l
        else
          i=$r
        fi
      elif [[ $2 < "$k" ]]; then
        i=${!lref}
      else
        i=${!rref}
      fi
    done

    # If the target kvpair to remove is not found, we just return.
    [[ $target ]] || return 1

    # Move the deepest adjacent kvpair at the "i" cell to the "target" cell.
    if ((target != (i = path[--d]))); then
      builtin eval "$dict"'_keys[target]=${!kref}'
      builtin eval "$dict"'_vals[target]=${!vref}'
    fi

    # Remove the "i" cell.  Note: since the loop stops when finding -1 on either
    # lptrs or rptrs, there is only one child at most.  We reconnect the child to
    # the parent.
    if ((${dict}_lptrs[i] != -1)); then
      impl4v#.path.reconnect-parent "${!lref}"
    else
      impl4v#.path.reconnect-parent "${!rref}"
    fi
    impl4v#.free "$i"

    # Rebalance and recalculate the depth
    while ((--d >= 0)); do
      impl4v#.path.rebalance "${path[d]}" && break
    done
  }

  ## @fn impl4v#.path.next
  ##   @var[ref] path d
  ##   @var[out] REPLY
  function impl4v#.path.next {
    local lref=${dict}_lptrs[i]
    local rref=${dict}_rptrs[i]
    local i=$((d == 0 ? ${dict}_root : ${dict}_rptrs[path[d >= 1 ? d - 1 : 0]]))
    if ((i >= 0)); then
      while ((path[d++] = i, (i = lref) >= 0)); do
        continue
      done
    else
      while ((--d >= 1)) && ((i = path[d-1], rref == path[d])); do
        continue
      done
    fi
    ((d >= 1)) || return 1
    REPLY=${path[d-1]}
  }

  function impl4v#keys {
    local dict=$1
    REPLY=()
    local d=0 path i=0
    local kref=${dict}_keys[REPLY]
    while impl4v#.path.next; do
      REPLY[i++]=${!kref}
    done
  }
fi

#------------------------------------------------------------------------------
# Results: The benchmark test has been done in Bash 3.0.
#
# 0. impl0: For reference, let us measure the performance of the built-in
#   associative array of Bash >= 4.0.
#
#   command               # bash-5.3
#   test_rand impl0 10    # 0.000 0.005ms
#   test_rand impl0 100   # 0.001 0.005ms
#   test_rand impl0 1000  # 0.008 0.005ms
#   test_rand impl0 10000 # 0.076 0.004ms
#   test_seq  impl0 10    # 0.000 0.005ms
#   test_seq  impl0 100   # 0.001 0.005ms
#   test_seq  impl0 1000  # 0.007 0.004ms
#   test_seq  impl0 10000 # 0.072 0.004ms
#
#   Note: The first number is the time of construction. The second number is
#   the access time.
#
# 1. impl1: The current implementation of the search using glob matching.  glob
#   探索は要素数が増えると爆発的に時間が増えるので全然駄目だ。というか構築がそ
#   もそも死にそうに遅い。構築の時に既存要素を探索するのでそれが原因。
#
#   test_rand impl1 10   # 0.001s   0.101ms
#   test_rand impl1 100  # 0.016s   3.792ms
#   test_rand impl1 1000 # 7.909s 459.000ms
#
# 2. impl2: The linear search by the direct Bash loop. これも構築速度が致命的。
#
#   test_rand impl2 10   # 0.001s 0.092ms
#   test_rand impl2 100  # 0.053s 0.511ms
#   test_rand impl2 1000 # 5.472s 5.340ms
#
# 3. impl3: When the two arrays (for keys and values) in impl2 are zipped into
#   a single array. impl2 の時よりも悪化している。
#
#   test_rand impl3 10   # 0.001s 0.086ms
#   test_rand impl3 100  # 0.050s 0.512ms
#   test_rand impl3 1000 # 6.013s 5.740ms
#
# 4. impl4: AVL tree straightforwardly constructed on arrays.
#
#   rebalance 実装前: 1万要素追加するとさすがに構築に時間がかかるが、以前の実装
#   よりは断然高速である。
#
#   test_rand impl4 10    # 0.002s 0.121ms
#   test_rand impl4 100   # 0.027s 0.267ms
#   test_rand impl4 1000  # 0.417s 0.439ms
#   test_rand impl4 10000 # 6.269s 0.706ms
#
#   rebalance 実装後: random 追加の場合で比較すると rebalance によって2.5倍ぐら
#   い遅くなっている。これはどの大きさでも共通であって、大きくなると悪化すると
#   かはない。sequential 追加したら流石に rebalance が重いのだろう。構築時間が
#   大きくなる。それでもその他の線形探索と比べたら現実的な範囲に収まっている。
#
#   bash の version を変えても安定していて特定の version で遅くなるという事もな
#   い。因みに bash-5.3 では使わないが配列自体の最適化によりさらに高速になって
#   いる。
#
#   impl/check-unset impl4
#
#   command               # bash-3.0        bash-3.2        bash-4.1          bash-5.3
#   test_rand impl4 10    #  0.006s 0.101ms  0.004s 0.074ms  0.004s  80.100ms 0.002s 0.034ms
#   test_rand impl4 100   #  0.066s 0.123ms  0.059s 0.133ms  0.070s 165.000ms 0.032s 0.057ms
#   test_rand impl4 1000  #  0.862s 0.239ms  0.800s 0.199ms  0.832s 231.000ms 0.388s 0.104ms
#   test_rand impl4 10000 # 14.386s 0.449ms 13.686s 0.576ms 13.667s 571.000ms 6.144s 0.218ms
#   test_seq  impl4 10    #  0.005s 0.058ms  0.005s 0.053ms  0.005s  57.550ms 0.003s 0.027ms
#   test_seq  impl4 100   #  0.084s 0.160ms  0.079s 0.146ms  0.084s 158.000ms 0.042s 0.066ms
#   test_seq  impl4 1000  #  1.159s 0.241ms  1.079s 0.225ms  1.131s 239.000ms 0.514s 0.101ms
#   test_seq  impl4 10000 # 29.510s 0.856ms 29.276s 0.826ms 28.801s 836.000ms 9.508s 0.473ms
#
#   impl/check-unset impl4a
#   impl4a#clear
#
#   変数名を指定できる様に拡張した物。eval "${script//DICT/$dict}" はかなり遅く
#   なるが、できるだけ算術式などを介してアクセスする様にしたら直接実装した時と
#   殆ど変わらない速度になった。なので、変数名を指定できる事による overhead は
#   ほぼ無視できる。
#
#   command                # (1) eval script  (2) arithmetic  (3) use_varref
#   test_rand impl4a 10    # 0.020s 0.261ms    0.005s 0.099ms  0.005s 0.101ms
#   test_rand impl4a 100   # 0.309s 0.321ms    0.079s 0.162ms  0.078s 0.179ms
#   test_rand impl4a 1000  # 3.460s 0.415ms    0.983s 0.249ms  0.907s 0.293ms
#   test_rand impl4a 10000 #                  15.179s 0.596ms 14.827s 0.586ms
#   test_seq  impl4a 10    # 0.029s 0.227ms    0.007s 0.077ms  0.007s 0.076ms
#   test_seq  impl4a 100   # 0.409s 0.323ms    0.099s 0.179ms  0.094s 0.180ms
#   test_seq  impl4a 1000  # 4.661s 0.405ms    1.317s 0.265ms  1.222s 0.262ms
#   test_seq  impl4a 10000 #                  31.575s 0.872ms 30.695s 0.891ms

function measure-refget {
  local dict=impl4a
  local -a impl4a_lptrs=(-1)

  function i0 {
    local i=$1
  }
  function i1 {
    local i=$1 ref=${dict}_lptrs[i]
    REPLY=${!ref}
  }
  function i2 {
    local i=$1
    ((REPLY=${dict}_lptrs[i]))
  }
  function i3 {
    local i=$1
    REPLY=$((${dict}_lptrs[i]))
  }
  i4ref=${dict}_lptrs[i]
  function i4 {
    local i=$1
    REPLY=${!i4ref}
  }

  ble-measure -c20 'i0 0' #  5.370 usec
  ble-measure -c20 'i1 0' # 16.080 usec
  ble-measure -c20 'i2 0' # 13.680 usec
  ble-measure -c20 'i3 0' # 14.280 usec
  ble-measure -c20 'i4 0' # 12.080 usec
}

#measure-refget
