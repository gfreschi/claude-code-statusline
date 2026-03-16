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

11 segments packed into a Powerline-style bar:

| Segment | What it shows |
|---------|---------------|
| **Model** | Current model (Opus, Sonnet, Haiku) with distinct color per model |
| **Agent** | Active subagent name when dispatched |
| **Context** | Dot gauge, percentage, token counts, time until auto-compaction |
| **Burn rate** | Tokens per minute consumption |
| **Cache** | Cache hit ratio for the session |
| **Project** | Working directory name with clickable OSC 8 link |
| **Git** | Branch, dirty flag, ahead/behind counts, stash count |
| **Lines** | Net lines added/removed this session |
| **Worktree** | Git worktree indicator |
| **Duration** | Session time with color escalation |
| **Micro location** | Compact project + branch pill for narrow terminals |

### Adapts to Your Terminal

The layout adjusts automatically based on terminal width:

<p align="center">
  <img src="images/tiers.gif" alt="Layout tiers" width="800">
</p>

| Tier | Width | Layout |
|------|-------|--------|
| **Full** | >= 120 cols | Two rows, all 11 segments |
| **Compact** | 80-119 cols | One row: model, context, project, duration |
| **Micro** | < 80 cols | Minimal pill: abbreviated model, percentage, location |

## Themes

<p align="center">
  <img src="images/themes.gif" alt="Bundled themes" width="800">
</p>

Four bundled themes. Set via environment variable:

```sh
export CLAUDE_STATUSLINE_THEME="dracula"
```

Available: `catppuccin-mocha` (default), `bluloco-dark`, `dracula`, `nord`

Create your own with 12 color variables, or [port your existing terminal theme](CONTRIBUTING.md#porting-an-existing-terminal-theme). Full guide: [Adding a Theme](CONTRIBUTING.md#adding-a-theme).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_STATUSLINE_THEME` | `catppuccin-mocha` | Theme name |
| `CLAUDE_STATUSLINE_NERD_FONT` | `1` | Set to `0` for ASCII fallbacks |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` | Compaction countdown target % |

## How It Works

`main.sh` receives JSON from Claude Code via stdin, extracts fields with a single `jq` call, and outputs ANSI-colored Powerline rows. Git state is cached with a 5s TTL to avoid lag on large repos. The entire thing is POSIX `sh`: works with `sh`, `dash`, `bash`, and `zsh`.

See [CLAUDE.md](CLAUDE.md) for the full architecture reference.

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and guides for adding segments and themes.

## License

[MIT](LICENSE)
