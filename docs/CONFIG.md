# Configuration

All configuration is via environment variables. They can be set inline, exported from a shell profile, or placed in a config file that `main.sh` sources at startup.

## Config file

Default path: `~/.config/claude-statusline/config.sh`. Override with `CLAUDE_STATUSLINE_CONFIG_FILE=/absolute/path.sh`.

The file is sourced as POSIX shell at the very top of `main.sh`, before any other logic runs. This means:

- Only assign `CLAUDE_STATUSLINE_*` variables. Do not run commands with side effects (`curl`, `rm`, `echo` to stderr, etc.) -- anything they print will corrupt the status line output.
- The config file is executed with your login shell's permissions. Do not source configs you did not write yourself.
- Unknown values fall back to the documented default silently; there is no validation error.

Example:

```sh
# ~/.config/claude-statusline/config.sh
CLAUDE_STATUSLINE_THEME=dracula
CLAUDE_STATUSLINE_LAYOUT=zen
CLAUDE_STATUSLINE_RATE_STYLE=ember
CLAUDE_STATUSLINE_CTX_GAUGE=blocks
CLAUDE_STATUSLINE_CAP_STYLE=capsule
```

Any env var set in your current shell still wins over the config file -- `main.sh` sources the file first, so later `CLAUDE_STATUSLINE_*=value sh main.sh` invocations override it.

## Environment variables

| Name | Default | Values | Effect |
|------|---------|--------|--------|
| `CLAUDE_STATUSLINE_THEME` | `catppuccin-mocha` | any file under `lib/themes/` (without `.sh`) | Selects the palette file to source |
| `CLAUDE_STATUSLINE_NERD_FONT` | `1` | `0` / `1` | `0` disables Nerd Font glyphs and falls back to ASCII |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` | integer 50-99 | Target % used by the context countdown |
| `CLAUDE_STATUSLINE_LAYOUT` | `classic` | `classic` / `zen` | `zen` unlocks the 3-row layout (requires width >= 140) |
| `CLAUDE_STATUSLINE_RATE_STYLE` | `ember` | `ember` / `bar` / `pill` / `minimal` | Visual preset for `segment_rate_limit` |
| `CLAUDE_STATUSLINE_CTX_GAUGE` | `dots` | `dots` / `blocks` / `braille` / `pips` | Glyph family used by the context gauge |
| `CLAUDE_STATUSLINE_CAP_STYLE` | `powerline` | `powerline` / `capsule` | Row-edge cap shape (Powerline triangle vs. rounded capsule) |
| `CLAUDE_STATUSLINE_SEGMENTS` | (unset) | comma-separated segment basenames | Overrides the default segment list, e.g. `model,context,git,duration` |
| `CLAUDE_STATUSLINE_MINIMAL` | `0` | `0` / `1` | `1` strips icons and word labels while preserving color and structure |
| `CLAUDE_STATUSLINE_CONFIG_FILE` | `$HOME/.config/claude-statusline/config.sh` | absolute path | Alternate config-file location |

Validation rule: unknown values silently fall back to the documented default. No error message is printed, because stdout is the status line itself.

### `CLAUDE_STATUSLINE_SEGMENTS` override

Provide a comma-separated list of segment basenames (the file name under `lib/segments/` without the `.sh` extension, or equivalently the `segment_` function suffix). Unknown names are silently dropped.

```sh
# Minimal session row only
CLAUDE_STATUSLINE_SEGMENTS=model,context,duration

# Dev workflow focus
CLAUDE_STATUSLINE_SEGMENTS=model,context,git,lines,worktree
```

When the override resolves to an empty list (all names unknown), the default `SL_SEGMENTS` list is used instead so the status line never renders blank.

## Layout tiers

The renderer picks one of four tiers based on `$COLUMNS` and `$CLAUDE_STATUSLINE_LAYOUT`:

| Tier | Width | Rows |
|------|-------|------|
| Zen | >= 140 cols AND `LAYOUT=zen` | 3 (session, workspace, ambient) |
| Full | >= 120 cols | 2 (session, workspace) |
| Compact | 80-119 cols | 1 |
| Micro | < 80 cols | 1 |

Zen falls back to Full/Compact/Micro automatically when the terminal is narrower than 140 cols, so leaving `LAYOUT=zen` set permanently is safe.

## Adaptive slots

Two segments rotate conditionally. Each emits only the first match in its priority list, or nothing / a fallback when nothing fires.

**`alerts_slot`** (Row 1 / session group, `min_tier=full`):

1. `cache-poor` -- cache hit ratio `< 70%` and cache reads > 0
2. `added-dirs` -- at least one directory added via `/add-dir`
3. `7d-warning` -- zen mode only, and 7d rate used `>= 70%`

When no condition matches, `alerts_slot` emits nothing and leaves the width free.

**`info_slot`** (Row 3 ambient in zen, Row 2 workspace fallback in classic, `min_tier=full`):

1. `output-style` -- `/output-style` is non-default
2. `subdir` -- cwd is a proper descendant of `project_dir`
3. `session-name` -- `session_name` is set
4. `clock` -- always-true fallback

`info_slot` always renders something because of the clock fallback. When nothing else fires, it shows the current time.

## Rate-limit presets

`CLAUDE_STATUSLINE_RATE_STYLE` controls the `segment_rate_limit` visual. All presets share the same escalation logic -- the segment flips to the critical "burns in Xm" headline once projected burn would hit 100% before the 5h reset.

| Preset | Description |
|--------|-------------|
| `ember` (default) | Battery glyph state icon, progressive disclosure: hides 7d until >= 50% |
| `bar` | Fusion bar: length tracks elapsed time, color tracks pace state |
| `pill` | Rounded pill with plain percentage and reset countdown |
| `minimal` | Single-line percentage + reset; no icons, no pace arrow |

When `CLAUDE_STATUSLINE_MINIMAL=1` is set globally, every segment drops its icon and word labels regardless of preset, keeping only the numeric content and colors.

## Examples

### Calm, monochrome-ish setup

```sh
CLAUDE_STATUSLINE_THEME=nord
CLAUDE_STATUSLINE_MINIMAL=1
CLAUDE_STATUSLINE_CAP_STYLE=capsule
```

### Dense signals on a wide terminal

```sh
CLAUDE_STATUSLINE_LAYOUT=zen
CLAUDE_STATUSLINE_CTX_GAUGE=braille
CLAUDE_STATUSLINE_RATE_STYLE=bar
```

### Reduced segment set for narrow terminals only

```sh
CLAUDE_STATUSLINE_SEGMENTS=model,context,git,duration
```
