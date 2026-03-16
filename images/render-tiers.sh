#!/bin/sh
# Helper script for VHS: cycles through all tiers
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/mid.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

draw_tier() {
  _dt_label="$1"
  _dt_cols="$2"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}%s${C_RESET}" "$_dt_label"

  pos 4 1
  echo "$json" | COLUMNS="$_dt_cols" sh "$DIR/main.sh"

  sleep 3
}

clear
draw_tier "Full tier (>= 120 cols)"  140
draw_tier "Compact tier (80-119 cols)" 100
draw_tier "Micro tier (< 80 cols)"   60
