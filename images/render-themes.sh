#!/bin/sh
# Helper script for VHS screenshots: renders all themes with polished layout
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/full.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }
sep() { printf "${C_DIM}%s${C_RESET}" "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"; }

printf '\033[2J'
pos 1 1

_rt_row=2
for theme in catppuccin-mocha dracula nord bluloco-dark; do
  case "$theme" in
    catppuccin-mocha) _rt_label="catppuccin-mocha (default)" ;;
    *) _rt_label="$theme" ;;
  esac

  pos "$_rt_row" 3
  printf "${C_BOLD}${C_WHITE}%s${C_RESET}" "$_rt_label"
  _rt_row=$(( _rt_row + 1 ))

  pos "$_rt_row" 1
  echo "$json" | COLUMNS=100 CLAUDE_STATUSLINE_THEME="$theme" sh "$DIR/main.sh"
  _rt_row=$(( _rt_row + 1 ))

  pos "$_rt_row" 1
  sep
  _rt_row=$(( _rt_row + 2 ))
done

sleep 3
