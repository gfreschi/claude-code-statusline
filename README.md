<div align="center">

# claude-code-statusline

**A Powerline-style status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code)**

See your model, context window, git state, and session metrics at a glance.
Adaptive layout, swappable themes, zero compiled dependencies.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![POSIX sh](https://img.shields.io/badge/shell-POSIX%20sh-green.svg)]()
[![CI](https://github.com/gfreschi/claude-code-statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/gfreschi/claude-code-statusline/actions/workflows/ci.yml)

</div>

<br>

<p align="center">
  <img src="images/demo.gif" alt="Demo" width="800">
</p>

## Install

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/gfreschi/claude-code-statusline/main/install.sh)"
```

Restart Claude Code. Done.

> Requires [`jq`](https://jqlang.github.io/jq/) and a 256-color terminal. [Nerd Font](https://www.nerdfonts.com/) recommended for icons (falls back to ASCII).

<details>
<summary>Update, uninstall, or manual setup</summary>

```sh
sh ~/.claude/statusline/install.sh update      # pull latest
sh ~/.claude/statusline/install.sh uninstall   # remove completely
```

**Manual install** (if you prefer not to pipe curl):

```sh
git clone https://github.com/gfreschi/claude-code-statusline.git ~/.claude/statusline
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": "sh ~/.claude/statusline/main.sh"
}
```

</details>

## What You Get

A Powerline-style bar packed with live session signals:

| Segment | What it shows |
|---------|---------------|
| **Model** | Current model (Opus, Sonnet, Haiku) with distinct color per model |
| **Agent** | Active subagent name when dispatched |
| **Context** | Configurable gauge (dots, blocks, braille, pips), percentage, token counts, time until auto-compaction |
| **Rate-limit** | 5h usage pill with battery glyph, pace arrow, and `burns in 12m` escalation when overrunning |
| **Burn rate** | Tokens per minute with a small braille sparkline of the last 8 samples |
| **Alerts slot** | Priority-rotating pill: cache-hit-ratio warning (< 70%), added-dirs, or 7d rate warning |
| **Project** | Working directory name with clickable OSC 8 link |
| **Git** | Branch, staged / unstaged / untracked split, ahead/behind, stash, fork badge, conflict override |
| **Info slot** | Priority-rotating: non-default output style, subdir drift, session name, or clock |
| **Lines** | Net lines added/removed this session |
| **Worktree** | Git worktree indicator |
| **Duration** | Session time with API-time suffix and color escalation |
| **Micro location** | Compact project + branch pill for narrow terminals |

The always-on cache segment from v1 was retired. Cache hit ratio now appears only when it drops below 70%, via the adaptive alerts slot -- when caching is healthy, the line stays calm.

### Adapts to Your Terminal

The layout adjusts automatically based on terminal width:

<p align="center">
  <img src="images/tiers.gif" alt="Layout tiers" width="800">
</p>

| Tier | Width | Layout |
|------|-------|--------|
| **Full** | >= 120 cols | Two rows, session + workspace |
| **Compact** | 80-119 cols | One row: model, context, project, duration |
| **Micro** | < 80 cols | Minimal pill: abbreviated model, percentage, location |

### Zen layout

For wide terminals (>= 140 cols), opt into a 3-row "heavy-top" layout:

```sh
export CLAUDE_STATUSLINE_LAYOUT=zen
```

- **Row 1 (session)** -- the dynamic glance strip: model, context, rate-limit, burn-rate, alerts.
- **Row 2 (workspace)** -- the repo view: project, git, lines, worktree, duration.
- **Row 3 (ambient)** -- recessed supplemental info: stable 7d rate pill, output style, subdir, session name, or a clock fallback.

Below 140 cols, the status line falls back to Full/Compact/Micro automatically.

## Themes

<p align="center">
  <img src="images/themes.gif" alt="Bundled themes" width="800">
</p>

Four bundled themes. Set via environment variable:

```sh
export CLAUDE_STATUSLINE_THEME="dracula"
```

Available: `catppuccin-mocha` (default), `bluloco-dark`, `dracula`, `nord`

Browse all themes with detailed previews and palettes: **[THEMES.md](THEMES.md)**

Create your own with 12 color variables, or [port your existing terminal theme](CONTRIBUTING.md#porting-an-existing-terminal-theme).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_STATUSLINE_THEME` | `catppuccin-mocha` | Theme name (any file under `lib/themes/`) |
| `CLAUDE_STATUSLINE_NERD_FONT` | `1` | Set to `0` for ASCII fallbacks |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` | Compaction countdown target % |
| `CLAUDE_STATUSLINE_LAYOUT` | `classic` | `classic` (2 rows) or `zen` (3 rows, needs >= 140 cols) |
| `CLAUDE_STATUSLINE_RATE_STYLE` | `ember` | Rate-limit preset: `ember`, `bar`, `pill`, or `minimal` |
| `CLAUDE_STATUSLINE_CTX_GAUGE` | `dots` | Context gauge style: `dots`, `blocks`, `braille`, `pips` |
| `CLAUDE_STATUSLINE_CAP_STYLE` | `powerline` | Row caps: `powerline` triangles or `capsule` rounded ends |
| `CLAUDE_STATUSLINE_SEGMENTS` | (unset) | Comma-separated override of the default segment list |
| `CLAUDE_STATUSLINE_MINIMAL` | `0` | `1` strips icons and word labels (color preserved) |
| `CLAUDE_STATUSLINE_CONFIG_FILE` | `~/.config/claude-statusline/config.sh` | Alternate config-file path |

Unknown values silently fall back to the default so a typo never breaks the status line.

Full reference: [docs/CONFIG.md](docs/CONFIG.md).

### Config file

Instead of exporting many env vars, keep them in a shell file that is sourced at startup:

```sh
# ~/.config/claude-statusline/config.sh
CLAUDE_STATUSLINE_THEME=dracula
CLAUDE_STATUSLINE_LAYOUT=zen
CLAUDE_STATUSLINE_RATE_STYLE=ember
CLAUDE_STATUSLINE_CTX_GAUGE=blocks
```

Every `CLAUDE_STATUSLINE_*` variable is honored. The file is sourced as POSIX shell at the top of `main.sh`, so only use it to assign variables -- do not run side-effect commands from it.

## How It Works

`main.sh` receives JSON from Claude Code via stdin, extracts fields with a single `jq` call, and outputs ANSI-colored Powerline rows. Git state is cached with a 5s TTL to avoid lag on large repos. The entire thing is POSIX `sh`: works with `sh`, `dash`, `bash`, and `zsh`.

See [CLAUDE.md](CLAUDE.md) for the full architecture reference.

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and guides for adding segments and themes.

## License

[MIT](LICENSE)
