#!/bin/sh
# Helper script for VHS screenshots -- renders tiers cleanly
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/mid.json")

clear
printf '\033[1;97m Full tier (>= 120 cols)\033[0m\n'
echo "$json" | COLUMNS=140 sh "$DIR/main.sh"
printf '\n'
printf '\033[1;97m Compact tier (80-119 cols)\033[0m\n'
echo "$json" | COLUMNS=100 sh "$DIR/main.sh"
printf '\n'
printf '\033[1;97m Micro tier (< 80 cols)\033[0m\n'
echo "$json" | COLUMNS=60 sh "$DIR/main.sh"
