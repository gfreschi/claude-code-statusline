#!/bin/sh
# Helper script for VHS: toggles CLAUDE_STATUSLINE_CAP_STYLE (powerline / capsule).
DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Frozen wall clock matches test/run.sh's TEST_NOW so fixture resets_at
# timestamps produce deterministic time-remaining text across GIF regens.
export CLAUDE_STATUSLINE_NOW_OVERRIDE=1800000000

json=$(cat "$DIR/test/fixtures/full.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

draw_cap() {
  _dc_style="$1"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}CLAUDE_STATUSLINE_CAP_STYLE=%s${C_RESET}" "$_dc_style"

  pos 4 1
  echo "$json" | COLUMNS=140 CLAUDE_STATUSLINE_CAP_STYLE="$_dc_style" sh "$DIR/main.sh"

  sleep 4
}

clear
draw_cap powerline
draw_cap capsule
