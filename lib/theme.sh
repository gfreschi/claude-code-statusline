#!/bin/sh
# theme.sh -- Theme orchestrator
# Loads selected theme, runs derivation, sets ANSI constants.
# Theme selection: CLAUDE_STATUSLINE_THEME env var (default: catppuccin-mocha)

_sl_theme="${CLAUDE_STATUSLINE_THEME:-catppuccin-mocha}"
_sl_theme_file="$SL_LIB/themes/${_sl_theme}.sh"

# Fallback to default if theme file not found
if [ ! -f "$_sl_theme_file" ]; then
  _sl_theme_file="$SL_LIB/themes/catppuccin-mocha.sh"
fi

# Load theme (sets PALETTE_* and optional C_* overrides)
. "$_sl_theme_file"

# Derive semantic tokens from palette
. "$SL_LIB/derive.sh"

# ANSI control constants (theme-independent)
# Prefixed with SL_ to avoid collision with C_DIM (256-color value)
RST='\033[0m'
SL_DIM='\033[2m'
SL_UNDIM='\033[22m'
SL_BOLD='\033[1m'
SL_BLINK='\033[5m'
