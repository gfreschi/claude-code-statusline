#!/bin/sh
# Helper script for VHS: cycles through every CLAUDE_STATUSLINE_RATE_STYLE preset.
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/rate-warming.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

draw_style() {
  _dst_name="$1"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}CLAUDE_STATUSLINE_RATE_STYLE=%s${C_RESET}" "$_dst_name"

  pos 4 1
  echo "$json" | COLUMNS=140 CLAUDE_STATUSLINE_RATE_STYLE="$_dst_name" sh "$DIR/main.sh"

  sleep 3
}

clear
draw_style ember
draw_style bar
draw_style pill
draw_style minimal
