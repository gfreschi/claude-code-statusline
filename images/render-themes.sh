#!/bin/sh
# Helper script for VHS screenshots -- renders all themes
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/full.json")

clear
for theme in catppuccin-mocha dracula nord bluloco-dark; do
  case "$theme" in
    catppuccin-mocha) label="catppuccin-mocha (default)" ;;
    *) label="$theme" ;;
  esac
  printf '\033[1;97m %s\033[0m\n' "$label"
  echo "$json" | COLUMNS=140 CLAUDE_STATUSLINE_THEME="$theme" sh "$DIR/main.sh"
  printf '\n'
done
