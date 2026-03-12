#!/bin/sh
# themes/bluloco-dark.sh -- Bluloco Dark palette (with contrast fixes)
# Original palette from https://github.com/uloco/theme-bluloco-dark
#
# Role              | Hex     | 256
# Base BG           | #282c34 | 236
# Base FG           | #abb2bf | 249
# Alt BG (muted)    | #2c313a | 237
# Dim BG (recessed) | #262626 | 235
# Blue              | #3691ff | 33
# Gold              | #f9c859 | 221
# Green             | #3fc56b | 77
# Cyan              | #34bfd0 | 80
# Red               | #ff6480 | 204
# Orange            | #ff7b72 | 209
# Magenta           | #b267e6 | 134
# Dim text          | #636d83 | 246  (was 243, bumped for contrast on muted BG)

PALETTE_BG=236
PALETTE_FG=249
PALETTE_BG_ALT=237
PALETTE_BG_DIM=235
PALETTE_BLUE=33
PALETTE_GOLD=221
PALETTE_GREEN=77
PALETTE_CYAN=80
PALETTE_RED=204
PALETTE_ORANGE=209
PALETTE_MAGENTA=134
PALETTE_DIM=246

# Contrast fixes (spec Section 3):
# CTX Warming: BG 58 (olive) -> base BG. Gold FG carries signal alone.
C_CTX_WARMING_BG=236

# CTX Filling: BG 130 (orange-on-orange) -> 52 (dark red). Orange pops.
C_CTX_FILLING_BG=52

# Sonnet: BG 33 (bright blue, glary) -> 27 (deeper blue)
C_SONNET_BG=27

# Dim text on dim BG needs extra bump (spec: 243->247 on dim BG)
C_DUR_LOW=247
