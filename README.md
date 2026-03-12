# claude-code-statusline

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with swappable themes, adaptive layout, and Powerline-style rendering.

Built entirely in POSIX `sh` -- no bash dependencies, no compiled binaries, works on any Unix terminal.


## Features

- **Themeable** -- ships with 4 themes, create your own with 12 color variables
- **Adaptive layout** -- automatically adjusts to terminal width (2-row, 1-row, or compact pill)
- **Powerline arrows** between primary segments, thin pipes between secondary
- **Context gauge** with dot indicators, token counts, and compaction ETA
- **Nerd Font support** with automatic fallback to ASCII
- **OSC 8 hyperlinks** for project names and git branches (when supported)
- **Git integration** with branch, dirty state, ahead/behind, and stash count (cached with 5s TTL)

## Requirements

- POSIX-compatible shell (`sh`, `dash`, `bash`, `zsh`)
- `jq` for JSON parsing
- A terminal with 256-color support
- [Nerd Font](https://www.nerdfonts.com/) (optional, for icons)

## Installation

1. Clone the repository:

```sh
git clone https://github.com/gfreschi/claude-code-statusline.git ~/.claude/statusline
```

2. Configure Claude Code to use it. Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": "sh ~/.claude/statusline/main.sh"
}
```

3. Restart Claude Code. The status line appears below the input.

## Layout Tiers

The layout automatically adapts based on terminal width:

### Full (>= 120 cols) -- 2 rows

```
Row 1: [Model]>[Context gauge]>[burn-rate | cache-stats]>
Row 2: [Project | Git branch + details | Lines | Worktree]>[Duration]>
```

### Compact (80-119 cols) -- 1 row

```
[Model]>[Context dots % tokens]>[Git branch | Duration]>
```

### Micro (< 80 cols) -- 1 row

```
[Op 4.6]>[58%]>[project.. | branch..]>
```

## Themes

Set the theme via environment variable:

```sh
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"  # default
export CLAUDE_STATUSLINE_THEME="bluloco-dark"
export CLAUDE_STATUSLINE_THEME="dracula"
export CLAUDE_STATUSLINE_THEME="nord"
```

If the theme file is not found, it falls back to `catppuccin-mocha`.

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

The derivation layer (`derive.sh`) maps these 12 values to ~30 semantic tokens automatically. You can override any specific token by setting it directly in your theme file:

```sh
# Optional: override specific derived tokens
C_SONNET_BG=27          # deeper blue for Sonnet model
C_CTX_FILLING_BG=52     # dark red instead of derived value
```

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
    bluloco-dark.sh       # Bundled with contrast fixes
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

Each segment is a pure data function that sets metadata variables. The orchestrator (`render_row` in `lib.sh`) handles all rendering decisions:

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

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `CLAUDE_STATUSLINE_THEME` | `catppuccin-mocha` | Theme name (filename without `.sh`) |
| `CLAUDE_STATUSLINE_NERD_FONT` | `1` | Set to `0` to disable Nerd Font icons |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` | Context percentage at which compaction countdown targets |

## Testing

Run the test harness to see all tiers with sample data:

```sh
# Single scenario (minimal, mid, full, critical)
sh test.sh full

# With a specific theme
sh test.sh full dracula

# All scenarios
for s in minimal mid full critical; do sh test.sh "$s"; done

# All themes
for t in catppuccin-mocha bluloco-dark dracula nord; do sh test.sh mid "$t"; done
```

## License

[MIT](LICENSE)
