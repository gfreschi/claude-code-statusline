#!/bin/sh
# Helper script for VHS screenshots: renders all tiers with polished layout
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json=$(cat "$DIR/test/fixtures/mid.json")

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }
sep() { printf "${C_DIM}%s${C_RESET}" "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"; }

printf '\033[2J'
pos 1 1

# Full tier
pos 2 3
printf "${C_BOLD}${C_WHITE}Full tier${C_RESET}${C_DIM}  (>= 120 cols)${C_RESET}"
pos 3 1
echo "$json" | COLUMNS=140 sh "$DIR/main.sh"
pos 4 1
echo "$json" | COLUMNS=140 sh "$DIR/main.sh" 2>/dev/null | tail -1
# Actually the full tier outputs 2 lines via printf, both captured above.
# Let me just use the script output directly.

pos 6 1
sep

# Compact tier
pos 8 3
printf "${C_BOLD}${C_WHITE}Compact tier${C_RESET}${C_DIM}  (80-119 cols)${C_RESET}"
pos 9 1
echo "$json" | COLUMNS=100 sh "$DIR/main.sh"

pos 11 1
sep

# Micro tier
pos 13 3
printf "${C_BOLD}${C_WHITE}Micro tier${C_RESET}${C_DIM}  (< 80 cols)${C_RESET}"
pos 14 1
echo "$json" | COLUMNS=60 sh "$DIR/main.sh"

sleep 3
