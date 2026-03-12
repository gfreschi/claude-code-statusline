<div align="center">

# claude-code-statusline

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with swappable themes, adaptive layout, and Powerline-style rendering.

Built entirely in POSIX `sh` -- no bash dependencies, no compiled binaries.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![POSIX sh](https://img.shields.io/badge/shell-POSIX%20sh-green.svg)]()

</div>

---

## Why?

Claude Code ships with a minimal status line. If you want to see your context usage at a glance, know which model you're on, track session duration, or just want something that looks good in your terminal -- this replaces it with a Powerline-style bar that adapts to your terminal width and matches your color scheme.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Layout Tiers](#layout-tiers)
- [Themes](#themes)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Themeable** -- ships with 4 themes, create your own with 12 color variables
- **Adaptive layout** -- automatically adjusts to terminal width (2-row, 1-row, or compact pill)
- **Powerline arrows** between primary segments, thin pipes between secondary
- **Context gauge** with dot indicators, token counts, and compaction ETA
- **Model-aware coloring** -- Opus, Sonnet, and Haiku each get a distinct background
- **Nerd Font support** with automatic fallback to ASCII
- **OSC 8 hyperlinks** for project names and git branches (click to open on GitHub)
- **Git integration** with branch, dirty state, ahead/behind, and stash count (cached with 5s TTL)
- **Agent indicator** -- shows the active subagent name when dispatched
- **Session metrics** -- burn rate (tok/min), cache hit ratio, lines changed, duration

---

## Quick Start

**1. Clone:**

```sh
git clone https://github.com/gfreschi/claude-code-statusline.git ~/.claude/statusline
```

**2. Configure Claude Code** -- add to `~/.claude/settings.json`:

```json
{
  "statusLine": "sh ~/.claude/statusline/main.sh"
}
```

**3. Restart Claude Code.** The status line appears below the input.

### Requirements

- POSIX-compatible shell (`sh`, `dash`, `bash`, `zsh`)
- [`jq`](https://jqlang.github.io/jq/) for JSON parsing
- A terminal with 256-color support
- [Nerd Font](https://www.nerdfonts.com/) (optional, for icons)

---

## Layout Tiers

The layout automatically adapts based on terminal width:

| Tier | Width | Rows | Segments |
|------|-------|------|----------|
| **Full** | >= 120 | 2 | All 11 segments across two rows |
| **Compact** | 80-119 | 1 | Model + context + git + duration |
| **Micro** | < 80 | 1 | Abbreviated model + percentage + project/branch pill |

### Full (>= 120 cols)

```
Row 1: [Model]>[Agent]>[Context gauge + compaction ETA]>[burn-rate | cache-stats]>
Row 2: [Project | Git branch + details | Lines | Worktree]>[Duration]>
```

### Compact (80-119 cols)

```
[Model]>[Context dots % tokens]>[Project | Duration]>
```

### Micro (< 80 cols)

```
[Op 4.6]>[58%]>[project.. | branch..]>
```

---

## Themes

Four bundled themes. Set via environment variable:

```sh
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"  # default
export CLAUDE_STATUSLINE_THEME="bluloco-dark"
export CLAUDE_STATUSLINE_THEME="dracula"
export CLAUDE_STATUSLINE_THEME="nord"
```

Falls back to `catppuccin-mocha` if the theme file is not found.

### Creating a Theme

Create a file in `themes/` with 12 palette variables:

```sh
#!/bin/sh
# themes/my-theme.sh

PALETTE_BG=236          # terminal background
PALETTE_FG=249          # default text
PALETTE_BG_ALT=237      # muted/secondary background
PALETTE_BG_DIM=235      # recessed background
PALETTE_BLUE=33
PALETTE_GOLD=221
PALETTE_GREEN=77
PALETTE_CYAN=80
PALETTE_RED=204
PALETTE_ORANGE=209
PALETTE_MAGENTA=134
PALETTE_DIM=243         # subdued text
```

The derivation layer (`derive.sh`) maps these 12 values to ~30 semantic tokens automatically. You can override any specific token directly in your theme file:

```sh
# Optional: override specific derived tokens
C_SONNET_BG=27          # deeper blue for Sonnet model
C_CTX_FILLING_BG=52     # dark red instead of derived value
```

Test your theme:

```sh
sh test.sh full my-theme
```

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `CLAUDE_STATUSLINE_THEME` | `catppuccin-mocha` | Theme name (filename without `.sh`) |
| `CLAUDE_STATUSLINE_NERD_FONT` | `1` | Set to `0` to disable Nerd Font icons |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` | Context percentage at which compaction countdown targets |

---

## Architecture

```
claude-code-statusline/
  main.sh             # Entry point: JSON stdin -> ANSI rows
  theme.sh            # Theme orchestrator (loads theme + derive)
  derive.sh           # Maps 12 PALETTE_* -> ~30 C_* semantic tokens
  lib.sh              # Rendering engine (emit_segment, render_row, etc.)
  cache.sh            # Git state cache with 5s TTL
  themes/
    catppuccin-mocha.sh   # Default theme
    bluloco-dark.sh       # Bundled
    dracula.sh            # Bundled
    nord.sh               # Bundled
  segments/
    model.sh              # Model name (Opus/Sonnet/Haiku), tier-colored
    agent.sh              # Agent name (conditional)
    context.sh            # Context gauge with dots, tokens, compaction ETA
    burn-rate.sh          # Token consumption rate
    cache-stats.sh        # Cache hit ratio
    project.sh            # Project directory name
    git.sh                # Branch, dirty, ahead/behind, stash
    lines.sh              # Lines added/removed delta
    worktree.sh           # Git worktree indicator
    duration.sh           # Session duration with color escalation
    micro-location.sh     # Merged project+branch for micro tier
```

### Segment Weight System

Segments are classified by visual weight, which determines their background and separator style:

| Weight | Background | Separator | Use |
|--------|-----------|-----------|-----|
| **Primary** | Colored (per-segment) | Powerline arrow | Model, Context |
| **Secondary** | Muted | Thin pipe | Project, Git |
| **Tertiary** | Muted | Thin pipe | Burn-rate, Cache, Lines, Worktree |
| **Recessed** | Dim | Thin pipe | Duration (full tier) |

### How Segments Work

Each segment is a pure data function that sets metadata variables. The orchestrator (`render_row` in `lib.sh`) handles all rendering:

```sh
segment_example() {
  [ -z "$some_data" ] && return 1    # skip if no data

  _seg_weight="secondary"            # primary|secondary|tertiary|recessed
  _seg_min_tier="compact"            # micro|compact|full
  _seg_group="workspace"             # session|workspace
  _seg_content="my content"          # plain text, no ANSI
  _seg_icon="$GL_FOLDER"             # Nerd Font glyph (optional)
  _seg_bg=$C_MUTED_BG                # 256-color number
  _seg_fg=$C_BASE_FG                 # 256-color number

  return 0
}
```

See [`CLAUDE.md`](CLAUDE.md) for the full segment contract, variable naming conventions, and architecture details.

---

## Testing

```sh
# Run a scenario (minimal, mid, full, critical) across all 3 tiers
sh test.sh full

# With a specific theme
sh test.sh full dracula

# All scenarios
for s in minimal mid full critical; do sh test.sh "$s"; done

# All themes
for t in catppuccin-mocha bluloco-dark dracula nord; do sh test.sh mid "$t"; done

# Syntax check all files
find . -name '*.sh' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}
```

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development setup, style guide, and how to add segments or themes.

## License

[MIT](LICENSE)
