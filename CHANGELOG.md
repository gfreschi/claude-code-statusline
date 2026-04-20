# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

## [2.0.0] - 2026-04-20

### Added

- **Rate-limit segment.** New session-row segment that surfaces Claude Code's
  5-hour budget with a battery glyph, usage pill, and pace arrow. Configurable
  via `CLAUDE_STATUSLINE_RATE_STYLE` with four presets (`ember` default, `bar`,
  `pill`, `minimal`). Escalates to `burns in Nm` when projected to overrun.
- **Alerts slot.** Priority-rotating pill that emits one of cache-hit-ratio
  warning (< 70%), added-dirs indicator, or 7-day rate-limit warning. Silent
  when nothing is actionable.
- **Info slot.** Ambient slot with priority rotation: non-default output style,
  subdir drift (cwd vs. project root), session name, or clock fallback.
- **7-day rate-limit (stable).** Dedicated ambient segment (zen only) that
  surfaces the longer-range weekly limit.
- **Zen layout.** Opt-in three-row heavy-top layout for terminals >= 140 cols
  via `CLAUDE_STATUSLINE_LAYOUT=zen`. Falls back gracefully to classic when
  the terminal is narrower.
- **Context gauge variants.** `CLAUDE_STATUSLINE_CTX_GAUGE` accepts
  `dots` (default), `blocks`, `braille`, and `pips`.
- **Capsule row caps.** Rounded powerline caps via
  `CLAUDE_STATUSLINE_CAP_STYLE=capsule`.
- **Minimalist mode.** `CLAUDE_STATUSLINE_MINIMAL=1` strips icons and
  word labels while preserving color.
- **Per-segment override.** `CLAUDE_STATUSLINE_SEGMENTS` accepts a
  comma-separated list of segment basenames; unknown names are silently
  dropped.
- **Config-file loader.** Settings can now live in
  `~/.config/claude-statusline/config.sh` (overridable via
  `CLAUDE_STATUSLINE_CONFIG_FILE`).
- **Git segment enhancements.** Dirty indicator split into staged /
  unstaged / untracked counts; `REBASING N/M` and `MERGING` overrides
  during conflicts; fork badge when `origin` differs from `upstream`.
- **Duration segment enhancements.** Appends an `(api Nm)` suffix in full
  tier and escalates color when API-time dominates wall-time.
- **Burn-rate sparkline.** The burn-rate segment now renders a braille
  sparkline trajectory tail driven by a ring-buffer cache.
- **POSIX-safe int coercion.** New `to_int` helper (`lib/render.sh`)
  floors floats and coerces non-numeric input without tripping dash's
  `$(( ))` parse-error abort.

### Changed

- **Tier gate is hierarchical.** Zen inherits full's segments; full inherits
  compact's; compact inherits micro's. Prior layout accidentally stripped
  zen of burn-rate, alerts-slot, info-slot, lines, and worktree.
- **Side-effect work moved to `main.sh`.** The render orchestrator iterates
  segments up to three times per zen render, so `sparkline_push` and other
  side-effecting work now runs once per render in `main.sh` instead of
  being triggered by segment functions.
- **Control-character sanitization.** Strings extracted from JSON are now
  scrubbed of C0 control bytes at the `jq` boundary (once per render).
  Git-sourced fields are scrubbed before they hit the cache file. Segments
  are no longer responsible for sanitizing their inputs.
- **Sparkline push path collapsed to shell builtins.** Replaced
  `cat | tr | wc` pipelines and per-token `printf '%d'` subshells with
  POSIX parameter expansion. Removes ~12 forks per render; benchmark
  dropped to under the v2.0 regression threshold on macOS.
- **Docs updated end-to-end.** `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
  `THEMES.md`, and the new `docs/CONFIG.md` all reflect the v2 contract
  and env-var surface.

### Removed

- **Always-on `cache_stats` segment.** Cache hit ratio now surfaces only
  when it drops below 70%, via the alerts slot. When caching is healthy
  the status line stays calm.

### Fixed

- **Dash float-arithmetic abort.** Claude Code sometimes emits
  `used_percentage` as a float; the prior guard
  (`$((x + 0)) 2>/dev/null || x=default`) was a parse-time error under
  dash and aborted the shell before the fallback could fire. `to_int`
  resolves this.
- **Rate-limit reset clamp.** Timestamps far in the future or past no
  longer produce nonsense `Nh Nm` durations.
- **Git cache permissions.** Cache file is now created with mode 0600
  (sparkline buffer already had the same guard).
- **Empty-row suppression.** When `CLAUDE_STATUSLINE_SEGMENTS` filters
  every segment in a group, the empty row is no longer printed as a
  blank line.
- **Minimal mode alerts.** Unit prefixes (e.g. `!!`) are preserved when
  labels are stripped, so the alerts slot remains scannable.

### Security

- **ANSI injection defense.** Control characters (ESC, BEL, ...) are
  stripped from every string field at the JSON boundary. Branch names,
  repository paths, and session names supplied by untrusted callers can
  no longer spoof status-line output.
- **Cache files locked down.** Both the git cache and the sparkline
  ring buffer are written with mode 0600 so neighbouring accounts on a
  shared host cannot rewrite the shell code that the status line
  sources back.

[Unreleased]: https://github.com/gfreschi/claude-code-statusline/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/gfreschi/claude-code-statusline/releases/tag/v2.0.0
