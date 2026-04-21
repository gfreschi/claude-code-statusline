# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

## [2.0.1] - 2026-04-21

Visual-cleanup patch. Fixes semantic and rendering issues shipped in 2.0,
tightens the segment <-> orchestrator contract, and adds stripped-ANSI
snapshot tests so these regressions cannot recur.

### Fixed

- **Project pill now names the project, not the cwd.** `sl_project` derives
  from `workspace.project_dir` basename (falls back to cwd). Users working
  inside a subdirectory no longer see the leaf directory name in both the
  project pill and the subdir-drift info-slot at the same time.
- **Rate-limit percent is labelled consistently.** All states show
  `{N}% used`; the previous wording (`78% left` in ok, bare `65%` in warm,
  `92% left` in crit despite being 92% used) inverted meaning at exactly
  the moment users needed an accurate read.
- **Lines segment dropped the redundant net.** `+142 / -38` instead of
  `↗+104 (+142/-38)`. Non-unicode fallback (arrow == `+` or `-`) drops the
  sign to avoid `++142 / --38`.
- **Git ahead/behind use GL_UP / GL_DOWN.** `↑2 ↓1` replaces literal
  `^2 v1`. Fallback keeps `^`/`v`.
- **Fork badge is a distinct glyph.** `GL_FORK` (nf-oct-repo_forked,
  U+F402) no longer duplicates the git-branch icon.
- **Compact tier truncates long labels.** Project 20 chars, branch 24,
  agent 20, worktree 20, using `…` (U+2026) as the truncation marker.
  Long branch names no longer overflow the row.
- **Info-slot prefixes normalized.** Output-style uses `·`, subdir drift
  uses `/path` (with internal `…` when truncated), session keeps `@`.
  The clock fallback is suppressed in classic layouts and only fires on
  zen row 3.
- **Info-slot classic fallback moved to session row.** When the slot
  does fire in classic, it joins the model-adjacent row rather than
  jamming between branch and duration.
- **Separator reads as a separator.** `.` ornamental separators in
  `rate-limit.sh`, `info-slot.sh`, and `rate-limit-7d-stable.sh` become
  `·` (U+00B7). ASCII fallback keeps `.`.
- **Braille gauge off-by-one.** `ctx_gauge_render` mapped pct 89-99 to
  the full-saturation bucket; rounded division (`(pct*8+50)/100`) now
  puts 95% at the first full reading. Same rounding applied to the
  burn-rate sparkline.
- **Compaction countdown at sub-minute projections.** When
  `_cx_min_to_compact == 0` the suffix is now `compact <1min` instead
  of silently disappearing.
- **SGR attribute leak across same-BG segments.** `emit_segment` /
  `emit_on_muted` / `emit_recessed` emit a full `SL_RST + BG + FG` at
  every same-BG transition so `bold blink` on a prior segment does not
  inherit into the next.
- **Detail suffix state leak.** `_rr_detail` closes with full reset + BG
  + FG instead of `SL_UNDIM` alone.
- **Capsule left-cap on recessed-first rows.** `emit_recessed` delegates
  to `emit_segment` on first-emit so zen's ambient row gets its left cap
  when `CAP_STYLE=capsule`.
- **OSC 8 link wraps outside SGR attrs.** The hyperlink escapes bracket
  the entire padded segment text rather than nesting inside a bold/blink
  region, matching terminal expectations.
- **Dash / zsh glyph rendering.** All `\xNN` byte escapes in the glyph
  table converted to `\0NNN` octal, which dash's printf and zsh's
  builtin printf both interpret. Classic v2.0 tests passed on dash and
  zsh only because they checked exit code, not byte content.
- **Rate-limit compact tier keeps burn projection on crit.** `burns in
  Nm ↑` stays on ember+crit in compact tier; only the trailing suffix
  words (`reset`) drop for space.
- **Leading space in rate-limit compact.** `_rl_glyph` is defined only
  for the ember preset, so pill/bar/minimal no longer leak a stray
  leading space through the compact-tier override.

### Changed

- **7-day rate-limit renders in classic layouts too.** Dedicated
  `rate_limit_7d_stable` segment now emits on the session row in classic
  (tertiary weight) when `_sl_cols >= 150`. Zen behaviour unchanged
  (row 3, recessed). Inline `7d {pct}% used` fragment in the 5h pill is
  retired.
- **Test suite grew snapshot assertions.** `test/run.sh --check` now
  diffs ANSI-stripped rendered output against `test/snapshots/*.txt`
  golden files. `--update-snapshots` regenerates them. 126/126 on
  sh / dash / bash / zsh.
- **Deterministic test fixtures.** `resets_at` values are now anchored
  to `TEST_NOW=1800000000` via a new `CLAUDE_STATUSLINE_NOW_OVERRIDE`
  env var so snapshot diffs do not drift with wall-clock time.

### Added

- **Cherry-pick state detection.** `sl_git_op=CHERRY-PICK` surfaces when
  `CHERRY_PICK_HEAD` exists, mirroring the existing `MERGING` /
  `REBASING N/M` overrides.
- **Defensive orchestrator guards.** `_seg_weight` defaults to
  `tertiary` if a segment forgets to set it (previously silently
  dropped); `_seg_attrs` tokenizes on commas as well as whitespace so
  `"bold,blink"` typos still work.
- **`sl_truncate` helper.** Shared truncation helper in `render.sh` for
  segment labels; applied to project, git branch, worktree, agent, and
  micro-location.

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

[Unreleased]: https://github.com/gfreschi/claude-code-statusline/compare/v2.0.1...HEAD
[2.0.1]: https://github.com/gfreschi/claude-code-statusline/releases/tag/v2.0.1
[2.0.0]: https://github.com/gfreschi/claude-code-statusline/releases/tag/v2.0.0
