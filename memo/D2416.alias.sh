#!/usr/bin/env bash

rep_target=v1.sh
function rep { refact -bq "$1" "$2" "$rep_target"; }

function v1gen {
  local src=$1 dst=$2
  cp -f "$src" "$dst"
  local rep_target=$dst

  rep Red      Love
  rep Flamingo Rose
  rep Crust    Base
  rep Sapphire Foam
  rep Peach    Gold
  rep Surface0 Overlay
  rep f38ba8 b4637a
  rep 11111b faf4ed
  rep f2cdcd d7827e
  rep 74c7ec 56949f
  rep fab387 ea9d34
  rep 313244 f2e9e1

  # rep Surface1 Muted
  # rep 45475a 9893a5
  rep Surface1 Surface
  rep 45475a fffaf3

  rep Green Pine
  rep Sky Foam
  rep Yellow Gold
  rep Overlay2 Muted
  rep a6e3a1 286983
  rep 89dceb 56949f
  rep f9e2af ea9d34
  rep 9399b2 9893a5

  rep Overlay0 Subtle
  rep Rosewater Text
  rep 6c7086 797593
  rep f5e0dc 575279

  rep Blue     Iris
  rep Mauve    Iris
  rep Lavender Iris
  rep 89b4fa 907aa9
  rep cba6f7 907aa9
  rep b4befe 907aa9
}

function v2gen {
  local src=$1 dst=$2
  cp -f "$src" "$dst"
  local rep_target=$dst

  rep Red      Love
  rep Flamingo Rose
  rep Crust    Base
  rep Surface0 Overlay
  rep f38ba8 eb6f92
  rep f2cdcd ea9a97
  rep 11111b 232136
  rep 313244 393552

  rep Green     Pine
  rep Overlay2  Muted
  rep Overlay0  Subtle
  rep Rosewater Text
  rep a6e3a1 3e8fb0
  rep 9399b2 6e6a86
  rep 6c7086 908caa
  rep f5e0dc e0def4

  # rep Surface1 Muted
  # rep 45475a 9893a5
  rep Surface1 Surface
  rep 45475a 2a273f

  rep Sapphire Foam
  rep Sky      Foam
  rep 74c7ec 9ccfd8
  rep 89dceb 9ccfd8

  rep Peach    Gold
  rep Yellow   Gold
  rep fab387 f6c177
  rep f9e2af f6c177

  rep Blue     Iris
  rep Mauve    Iris
  rep Lavender Iris
  rep 89b4fa c4a7e7
  rep cba6f7 c4a7e7
  rep b4befe c4a7e7
}

# v1gen catppuccin_mocha.bash.bk v1.sh
# diff -bwu v1.sh rosepine_dawn.bash > v1.diff
# v2gen catppuccin_mocha.bash.bk v2.sh
# diff -bwu v2.sh rosepine_moon.bash > v2.diff

# v1gen catppuccin_mocha.bash v1new.bash
# v2gen catppuccin_mocha.bash v2new.bash

function refactor-alias-names-for-catppuccin {
  local rep_target=$1
  rep scheme3  basic1
  rep scheme4  basic0
  rep scheme7  basic3
  rep scheme9  basic4
  rep scheme10 basic2
  rep scheme8  cursor
  rep scheme1  custom1
  rep scheme2  custom2
  rep scheme5  custom3
  rep scheme6  custom4
  rep scheme11 custom5
  rep scheme12 custom6
  rep scheme13 custom7
  rep scheme14 custom8
  rep scheme15 custom9
  rep scheme16 custom10
}
# refactor-alias-names-for-catppuccin catppuccin_mocha.bash
# refactor-alias-names-for-catppuccin rosepine_dawn.bash
# refactor-alias-names-for-catppuccin rosepine_moon.bash

function refactor-alias-names-for-tokyonight {
  local rep_target=$1
  rep scheme1  basic0
  rep scheme5  basic1
  rep scheme4  basic2
  rep scheme9  basic3
  rep scheme7  basic4
  rep scheme3  basic5
  rep scheme15 basic6
  rep scheme16 basic7
  rep scheme2  basic15
  rep scheme6  custom1
  rep scheme8  custom2
  rep scheme13 custom3
  rep scheme10 custom4
  rep scheme11 custom5
  rep scheme12 custom6
  rep scheme14 custom7
}
refactor-alias-names-for-tokyonight tokyo_night.bash

