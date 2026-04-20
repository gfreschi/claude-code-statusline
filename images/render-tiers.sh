#!/bin/sh
# Helper script for VHS: cycles through all tiers (zen, full, compact, micro).
# Zen gets its own fixture because it shows off rate-limit + ambient row
# (alerts, info slots, stable 7d pill) that the basic `mid.json` fixture
# does not exercise.
DIR="$(cd "$(dirname "$0")/.." && pwd)"

mid_json=$(cat "$DIR/test/fixtures/mid.json")
zen_json=$(cat "$DIR/test/fixtures/zen-full.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

draw_tier() {
  _dt_label="$1"
  _dt_cols="$2"
  _dt_json="$3"
  _dt_layout="$4"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}%s${C_RESET}" "$_dt_label"

  pos 4 1
  if [ -n "$_dt_layout" ]; then
    echo "$_dt_json" | COLUMNS="$_dt_cols" CLAUDE_STATUSLINE_LAYOUT="$_dt_layout" sh "$DIR/main.sh"
  else
    echo "$_dt_json" | COLUMNS="$_dt_cols" sh "$DIR/main.sh"
  fi

  sleep 3
}

clear
draw_tier "Zen tier (>= 140 cols, opt-in)" 150 "$zen_json" zen
draw_tier "Full tier (>= 120 cols)"        140 "$mid_json" ""
draw_tier "Compact tier (80-119 cols)"     100 "$mid_json" ""
draw_tier "Micro tier (< 80 cols)"          60 "$mid_json" ""
