#!/bin/sh
# themes/catppuccin-mocha.sh -- Catppuccin Mocha palette
# https://github.com/catppuccin/catppuccin
#
# Mocha is the highest-contrast dark flavor.
# Hex -> 256-color mappings use closest xterm-256 match.

# Role              | Catppuccin name | Hex     | 256
# Base BG           | Base            | #1e1e2e | 234
# Base FG           | Text            | #cdd6f4 | 188
# Alt BG (muted)    | Surface0        | #313244 | 236
# Dim BG (recessed) | Mantle          | #181825 | 233
# Blue              | Blue            | #89b4fa | 111
# Gold              | Yellow          | #f9e2af | 223
# Green             | Green           | #a6e3a1 | 151
# Cyan              | Teal            | #94e2d5 | 158
# Red               | Red             | #f38ba8 | 211
# Orange            | Peach           | #fab387 | 216
# Magenta           | Mauve           | #cba6f7 | 183
# Dim text          | Overlay0        | #6c7086 | 243

PALETTE_BG=234
PALETTE_FG=188
PALETTE_BG_ALT=236
PALETTE_BG_DIM=233
PALETTE_BLUE=111
PALETTE_GOLD=223
PALETTE_GREEN=151
PALETTE_CYAN=158
PALETTE_RED=211
PALETTE_ORANGE=216
PALETTE_MAGENTA=183
PALETTE_DIM=243

# Context gauge BG overrides (Catppuccin-specific dark tints)
# Healthy: darkened green (Surface0 has a blue tint, so use a green-biased dark)
C_CTX_HEALTHY_BG=22
# Filling: dark red tint
C_CTX_FILLING_BG=52
# Soon/Crit: same dark red
C_CTX_SOON_BG=52
C_CTX_CRIT_BG=52

# Sonnet: slightly deeper blue for less glare
C_SONNET_BG=69
