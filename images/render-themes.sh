#!/bin/sh
# Helper script for VHS: cycles through all themes
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/full.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

draw_theme() {
  _dt_theme="$1"
  _dt_label="$2"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}%s${C_RESET}" "$_dt_label"

  pos 4 1
  echo "$json" | COLUMNS=140 CLAUDE_STATUSLINE_THEME="$_dt_theme" sh "$DIR/main.sh"

  sleep 3
}

clear
draw_theme "catppuccin-mocha" "catppuccin-mocha (default)"
draw_theme "dracula"          "dracula"
draw_theme "nord"             "nord"
draw_theme "bluloco-dark"     "bluloco-dark"
