# CLAUDE.md

This file provides guidance to Claude Code and other AI assistants when working with this codebase. It also serves as architecture documentation for human contributors.

## Project Overview

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) built entirely in POSIX `sh`. It receives JSON via stdin, parses it with `jq`, and outputs ANSI-colored Powerline-style rows to the terminal. The layout adapts to terminal width across four tiers (zen, full, compact, micro).

## Tech Stack

- **Language:** POSIX sh (must work with `sh`, `dash`, `bash`, `zsh`)
- **Dependencies:** `jq` (JSON parsing), 256-color terminal
- **Optional:** Nerd Font (icons), OSC 8 (hyperlinks)

## Architecture

### Execution Flow

```
Claude Code -> stdin (JSON) -> main.sh -> stdout (ANSI rows)
```

`main.sh` is the entry point. It:
1. Optionally sources `$CLAUDE_STATUSLINE_CONFIG_FILE` (default `~/.config/claude-statusline/config.sh`) so users can set env vars without exporting them globally
2. Sources `theme.sh` (which loads theme file + `derive.sh`)
3. Sources `render.sh` (rendering engine)
4. Detects terminal width tier (`COLUMNS`) and layout mode (`CLAUDE_STATUSLINE_LAYOUT`)
5. Extracts JSON fields via a single `jq` call
6. Sources `cache.sh` and refreshes git state
7. Sources all `segments/*.sh` (defines functions, no execution)
8. Resolves an optional `CLAUDE_STATUSLINE_SEGMENTS` override against the default `SL_SEGMENTS` list
9. Calls `render_row()` once per row group (session / workspace / ambient)

### File Responsibilities

| File | Role |
|------|------|
| `main.sh` | Entry point: JSON parsing, tier detection, row assembly |
| `lib/theme.sh` | Orchestrator: loads theme via `CLAUDE_STATUSLINE_THEME` env var, sources `derive.sh`, sets `SL_*` ANSI constants |
| `lib/derive.sh` | Maps 12 `PALETTE_*` variables to ~30 `C_*` semantic tokens via `${VAR:-default}` pattern |
| `lib/render.sh` | Rendering engine: `emit_segment()`, `emit_on_muted()`, `emit_recessed()`, `emit_thin_sep()`, `emit_end()`, `render_row()` orchestrator, capability detection, glyph definitions |
| `lib/cache.sh` | Git state cache with 5s TTL using per-user temp directory (`$TMPDIR`) |
| `lib/themes/*.sh` | Theme files defining 12 `PALETTE_*` vars + optional `C_*` overrides |
| `lib/segments/*.sh` | Each defines a `segment_*()` function returning metadata via `_seg_*` variables |
| `install.sh` | Lifecycle manager: install, update, uninstall |
| `test/run.sh` | Test harness: visual + check modes, --shell flag for multi-shell testing |
| `test/fixtures/*.json` | JSON scenario payloads: minimal, mid, full, critical, rate-healthy, rate-warming, rate-critical, rate-float, zen-full |

### Four-Tier Adaptive Layout

Determined by `$COLUMNS` and `$CLAUDE_STATUSLINE_LAYOUT` at runtime:

| Tier | Width | Rows | Content |
|------|-------|------|---------|
| Zen | >= 140 | 3 | Opt-in via `CLAUDE_STATUSLINE_LAYOUT=zen`. Row 1 session, Row 2 workspace, Row 3 ambient |
| Full | >= 120 | 2 | Row 1 session, Row 2 workspace |
| Compact | 80-119 | 1 | Model + context + project + git + duration |
| Micro | < 80 | 1 | Abbreviated model + ctx% + project/branch pill |

Zen mode only activates when both conditions hold. If `LAYOUT=zen` is set but width is below 140, the status line falls back to Full/Compact/Micro as usual.

### Segment Contract

Every segment is a **pure data function**. It sets `_seg_*` metadata variables and returns 0 (render) or 1 (skip). The `render_row()` orchestrator in `render.sh` handles all rendering decisions.

**Metadata variables set by segments:**

| Variable | Values | Purpose |
|----------|--------|---------|
| `_seg_weight` | `primary`, `secondary`, `tertiary`, `recessed` | BG/FG treatment, separator style |
| `_seg_min_tier` | `zen`, `full`, `compact`, `micro` | Minimum tier to display (see note below) |
| `_seg_group` | `session`, `workspace`, `ambient` | Row assignment in multi-row tiers |
| `_seg_group_fallback` | `session`, `workspace`, or empty | Group to use when `$_sl_layout != "zen"` (classic). Empty means "hide outside zen" |
| `_seg_content` | plain text | Display text -- no ANSI escapes |
| `_seg_icon` | glyph var or empty | Nerd Font icon, orchestrator adds it |
| `_seg_bg` | 256-color number | Used by primary weight |
| `_seg_fg` | 256-color number | Used by primary; tertiary/recessed default to `C_DIM` if empty |
| `_seg_attrs` | `"bold"`, `"bold blink"`, or empty | Orchestrator wraps content in ANSI attrs |
| `_seg_detail` | text or empty | Rendered in dim after main content (e.g., git ahead/behind) |
| `_seg_link_url` | URL or empty | OSC 8 hyperlink target; orchestrator wraps `_seg_content` if set |

**Segments must NOT embed raw ANSI escapes in `_seg_content`.** Use `_seg_link_url` for OSC 8 hyperlinks -- the orchestrator wraps the content.

**Hard rules enforced by the orchestrator:**

- `_seg_group=ambient` combined with any `_seg_weight != recessed` is force-demoted to `recessed`. The ambient row is recessed-only by contract.
- `_seg_group_fallback` is honored only when `$_sl_layout = "classic"`. In zen mode the segment stays in its declared `_seg_group`.
- `_seg_min_tier=zen` is not a gate the orchestrator enforces via the tier switch -- segments that should only appear in zen self-gate on `$_sl_layout` at the top of the function and return 1 otherwise. Declaring `min_tier=zen` is informational for readers.

### Weight System and Separators

| Weight | Background | Separator to next | Typical use |
|--------|-----------|-------------------|-------------|
| Primary | Colored (per-segment) | Powerline arrow | Model, Context, Rate-limit |
| Secondary | `C_MUTED_BG` | Thin pipe (same BG) | Project, Git |
| Tertiary | `C_MUTED_BG` | Thin pipe (same BG) | Burn-rate, Lines, Worktree |
| Recessed | `C_DIM_BG` | Thin pipe from muted | Duration (full tier), Ambient-row segments (zen) |

Rule: Powerline arrow between **different** BGs. Thin pipe between **same** BGs.

Row caps (first-segment left edge, last-segment right edge) are Powerline triangles by default. Set `CLAUDE_STATUSLINE_CAP_STYLE=capsule` to use rounded U+E0B6/U+E0B4 caps instead.

### Theme System

Themes define 12 `PALETTE_*` variables. `derive.sh` maps them to ~30 `C_*` semantic tokens. Themes can override any `C_*` token directly for fine-tuning.

**12 required palette variables:**
`PALETTE_BG`, `PALETTE_FG`, `PALETTE_BG_ALT`, `PALETTE_BG_DIM`, `PALETTE_BLUE`, `PALETTE_GOLD`, `PALETTE_GREEN`, `PALETTE_CYAN`, `PALETTE_RED`, `PALETTE_ORANGE`, `PALETTE_MAGENTA`, `PALETTE_DIM`

**Bundled themes:** catppuccin-mocha (default), bluloco-dark, dracula, nord

### Variable Naming Conventions

| Prefix | Scope | Example |
|--------|-------|---------|
| `PALETTE_*` | Base palette (set by theme files) | `PALETTE_BLUE=111` |
| `C_*` | Semantic color tokens (set by `derive.sh`) | `C_OPUS_BG`, `C_CTX_HEALTHY_FG` |
| `SL_*` | ANSI control constants (set by `theme.sh`) | `SL_DIM`, `SL_BOLD` |
| `SL_LIB` | Internal path | `$SL_DIR/lib` -- base path for sourcing lib/ modules |
| `SL_CAP_*` | Capability flags | `SL_CAP_NERD`, `SL_CAP_OSC8`, `SL_USE_CAPSULE` |
| `GL_*` | Glyph variables | `GL_POWERLINE`, `GL_BRANCH` |
| `sl_*` | Runtime state from JSON or git cache | `sl_model_id`, `sl_branch` |
| `_seg_*` | Segment metadata (reset per segment) | `_seg_weight`, `_seg_content`, `_seg_group_fallback` |
| `_sl_*` | Session-scoped internal vars | `_sl_tier`, `_sl_cols`, `_sl_layout` |
| `_xx_*` | Function-local vars (prefixed by function) | `_es_bg`, `_rr_icon`, `_cx_pct` |

**Runtime state variables added in v2** (set by `main.sh`, read by segments):

| Variable | Type | Source |
|----------|------|--------|
| `sl_rate_5h_pct` | integer 0-100 or empty | `.rate_limits.five_hour.used_percentage` |
| `sl_rate_5h_reset_ts` | unix epoch seconds or empty | `.rate_limits.five_hour.resets_at` |
| `sl_rate_7d_pct` | integer 0-100 or empty | `.rate_limits.seven_day.used_percentage` |
| `sl_rate_7d_reset_ts` | unix epoch seconds or empty | `.rate_limits.seven_day.resets_at` |
| `sl_output_style` | string or empty | `.output_style.name` |
| `sl_session_name` | string or empty | `.session_name` |
| `sl_added_dirs_count` | integer >= 0 | `length` of `.workspace.added_dirs` |
| `sl_api_duration_ms` | integer or empty | `.cost.total_api_duration_ms` |
| `sl_project_dir` | string or empty | `.workspace.project_dir` (falls back to `.cwd`) |
| `_sl_layout` | `classic` or `zen` | validated env var `CLAUDE_STATUSLINE_LAYOUT` |

**Glyph families added in v2** (set by `detect_capabilities` in `render.sh`):

| Family | Variables | Purpose |
|--------|-----------|---------|
| Battery | `GL_BATT_FULL`, `GL_BATT_MID`, `GL_BATT_LOW` | Rate-limit ember preset state icons |
| Fork | `GL_FORK` | Upstream-fork badge in git segment |
| Capsule caps | `GL_CAP_LEFT`, `GL_CAP_RIGHT` | Rounded row caps when `CAP_STYLE=capsule` |
| Blocks | `GL_BLK_FILLED`, `GL_BLK_EMPTY` | Context `blocks` gauge |
| Pips | `GL_PIP_FILLED`, `GL_PIP_EMPTY` | Context `pips` gauge |
| Braille | `GL_BRL_0` .. `GL_BRL_8` (9 buckets) | Context `braille` gauge + burn-rate sparkline |
| Arrows | `GL_UP`, `GL_DOWN` | Pace indicator in rate-limit, ahead/behind hints |

### Segment Registration Order

Defined in `main.sh` as `SL_SEGMENTS`. Order = left-to-right render position:

```
segment_model segment_agent segment_context
segment_rate_limit segment_burn_rate segment_alerts_slot
segment_micro_location
segment_project segment_git segment_info_slot
segment_rate_limit_7d_stable
segment_lines segment_worktree segment_duration
```

`CLAUDE_STATUSLINE_SEGMENTS` (comma-separated basenames, e.g. `model,context,git,duration`) overrides this list at runtime. Unknown names are silently dropped so a typo never leaks a `command not found` into the status line.

Segment groupings:

- `segment_model`, `segment_agent`, `segment_context`, `segment_rate_limit`, `segment_burn_rate`, `segment_alerts_slot` -> `session` group (Row 1)
- `segment_project`, `segment_git`, `segment_lines`, `segment_worktree`, `segment_duration` -> `workspace` group (Row 2)
- `segment_info_slot` -> `ambient` group in zen, falls back to `workspace` in classic
- `segment_rate_limit_7d_stable` -> `ambient` group; self-gates to zen only
- `segment_micro_location` -> micro-tier only

### Git State Variables

Set by `cache.sh` via `cache_refresh`. Available to segments:

`sl_branch`, `sl_is_detached`, `sl_is_dirty`, `sl_ahead`, `sl_behind`, `sl_stash_count`, `sl_github_base_url`

## Coding Conventions

- **POSIX sh only.** No bashisms (`[[ ]]`, arrays, `local`, process substitution). Test with `sh -n`.
- **No ANSI in segments.** Segments set `_seg_content` as plain text. The orchestrator handles all color/formatting.
- **Prefix all local variables** with `_xx_` where `xx` is a 2-3 letter function abbreviation to avoid collisions. POSIX sh has no `local` keyword, so all variables are global -- prefixing prevents accidental overwrites.
- **Use `${VAR:-default}` pattern** in derive.sh so themes can override any token.
- **`set -f`** is active in main.sh (globbing disabled). Temporarily re-enable with `set +f` if needed.
- **Never rely on `$(( x + 0 )) 2>/dev/null || x=default` to guard arithmetic.** Under `dash` a parse error in `$(( ))` (e.g. when `x="52.5"` — Claude Code emits floats) aborts the shell with exit 2; the `2>/dev/null || ...` fallback is a parse-time error, not a runtime one, and never runs. Use the `to_int` helper in `lib/render.sh` instead: `to_int _var "$sl_value" 0` — it floors floats and replaces non-integer strings with the default. All v2 segments follow this pattern.
- **Cache file security:** String values written to cache files must use single-quote escaping to prevent shell injection when the cache is sourced. Numeric values use `printf '%d'` which sanitizes to digits.
- **Control-character sanitization** happens at the `jq` extraction boundary in `main.sh` (via `gsub("[[:cntrl:]]"; "")` on string fields) and in `cache.sh` before writing git-sourced strings to the cache file. Segments can trust that `sl_*` variables are free of ESC / BEL / other C0 bytes, so rendered output cannot be spoofed by an attacker who controls a git branch name, repo path, or session name.
- **Side-effect-having work runs once per render, not per row group.** The render orchestrator iterates segments three times in zen (one pass per row group). Segments with side effects — e.g. `sparkline_push` — must live in `main.sh` (called once after `cache_refresh`) rather than inside a segment function, otherwise they execute N× per render and corrupt any ring-buffer they maintain.

## Testing

```sh
# Run a scenario (minimal, mid, full, critical, rate-healthy, rate-warming,
# rate-critical, rate-float, zen-full) across all tiers:
sh test/run.sh --scenario full

# Specify a theme:
sh test/run.sh --scenario full --theme dracula

# Test all scenarios (visual):
sh test/run.sh

# CI assertions (all scenarios x tiers x themes):
sh test/run.sh --check

# CI: test under a specific shell:
sh test/run.sh --check --shell dash

# Syntax check all files:
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}

# Check for bashisms:
grep -rn '\[\[' --include='*.sh' .
grep -rn '^[[:space:]]*local ' --include='*.sh' .

# Visually inspect the v2 env-var matrix (each var toggles one dimension):
COLUMNS=150 CLAUDE_STATUSLINE_LAYOUT=zen        cat test/fixtures/zen-full.json      | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_RATE_STYLE=bar    cat test/fixtures/rate-warming.json  | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_RATE_STYLE=pill   cat test/fixtures/rate-warming.json  | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_RATE_STYLE=minimal cat test/fixtures/rate-warming.json | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_CTX_GAUGE=blocks  cat test/fixtures/full.json          | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_CTX_GAUGE=braille cat test/fixtures/full.json          | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_CTX_GAUGE=pips    cat test/fixtures/full.json          | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_CAP_STYLE=capsule cat test/fixtures/full.json          | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_MINIMAL=1         cat test/fixtures/full.json          | sh main.sh
COLUMNS=130 CLAUDE_STATUSLINE_SEGMENTS=model,context,git,duration \
                                                cat test/fixtures/full.json          | sh main.sh
CLAUDE_STATUSLINE_CONFIG_FILE=/tmp/cfg.sh       cat test/fixtures/full.json          | sh main.sh

# Validate all semantic tokens for a theme:
CLAUDE_STATUSLINE_THEME=dracula SL_DIR=. SL_LIB=./lib sh -c '. ./lib/theme.sh
  for var in C_OPUS_BG C_OPUS_FG C_SONNET_BG C_SONNET_FG C_HAIKU_BG C_HAIKU_FG \
    C_BASE_BG C_BASE_FG C_MUTED_BG C_DIM_BG C_DIM C_WHITE \
    C_CTX_HEALTHY_BG C_CTX_HEALTHY_FG C_CTX_WARMING_BG C_CTX_WARMING_FG \
    C_CTX_FILLING_BG C_CTX_FILLING_FG C_CTX_SOON_BG C_CTX_SOON_FG \
    C_CTX_CRIT_BG C_CTX_CRIT_FG C_DUR_LOW C_DUR_MED C_DUR_HIGH C_DUR_CRIT \
    C_LINES_ADD C_LINES_DEL C_LINES_ZERO C_WORKTREE_FG C_CACHE_GOOD C_CACHE_POOR; do
    eval "val=\$$var"; [ -z "$val" ] && echo "MISSING: $var"
  done && echo "ALL OK"'
```

## Adding a New Segment

1. Create `lib/segments/my-segment.sh` with a `segment_my_segment()` function
2. Set all `_seg_*` metadata variables, return 0 to render or 1 to skip
3. Pick a row group:
   - `session` (Row 1): model-adjacent signals
   - `workspace` (Row 2): repo / cwd context
   - `ambient` (Row 3 in zen only): recessed supplemental info
4. If the segment belongs in `ambient` but should still appear in classic mode, also set `_seg_group_fallback=session` or `_seg_group_fallback=workspace`. Leave it empty to hide the segment outside zen.
5. Set `_seg_min_tier` to the narrowest tier that should still render it (`micro`, `compact`, `full`). Use `zen` as a readability hint only and self-gate inside the function (`[ "$_sl_layout" != "zen" ] && return 1`).
6. Add `segment_my_segment` to `SL_SEGMENTS` in `main.sh` at the desired position
7. Run `sh -n lib/segments/my-segment.sh` to verify syntax
8. Run `sh test/run.sh --scenario full` to verify rendering

## Adding a New Theme

1. Create `lib/themes/my-theme.sh` with all 12 `PALETTE_*` variables
2. Optionally override specific `C_*` tokens for fine-tuning contrast
3. Run `sh -n lib/themes/my-theme.sh` to verify syntax
4. Test: `sh test/run.sh --scenario full --theme my-theme`
5. Validate tokens: run the token validation command above with your theme name

## Design Decisions

- **Catppuccin Mocha as default:** Most widely adopted terminal theme across modern emulators. Industry standard for open source.
- **Project segment demoted to secondary:** Project name rarely changes within a session, so it doesn't need a colored primary BG. Grouping it with git on muted BG creates a cohesive "workspace" zone.
- **Duration changes weight by tier:** Recessed (dim BG) in full tier for ambient info. Tertiary (muted BG) in compact tier to save the visual step.
- **Agent shares model BG:** Thin pipe separator (same-BG rule) makes it feel like an extension of the model segment rather than a separate block.
- **Micro-location replaces project+git in micro tier:** Dedicated merged pill with truncation keeps micro under 50 chars.
- **`_seg_attrs` for bold/blink:** Segments declare text attributes as metadata. The orchestrator applies and resets ANSI -- segments never embed escapes.
- **No `set -e`:** Intentionally omitted. A status line should degrade gracefully to partial output on errors rather than producing no output at all. Individual failures (e.g., missing git, broken JSON) result in skipped segments, not a blank line.
- **Single `jq` call:** All JSON fields are extracted in one `jq` invocation with `@sh` quoting and `eval`. This avoids spawning multiple `jq` processes (one per field) which would add noticeable latency to every status line render.
- **Git cache with TTL:** Git operations are cached for 5 seconds in a per-user temp directory. Without caching, running `git status`, `git stash list`, etc. on every render would cause visible lag, especially on large repositories.
- **Zen inherits full's segments:** The tier gate in `render_row` is hierarchical, not flat — a segment with `_seg_min_tier="full"` also renders in zen. Without this, zen would ship as strictly less content than full (it would strip burn-rate, alerts-slot, info-slot, lines, worktree). The gate reads: `zen)` needs exactly zen; `full)` needs zen or full; `compact)` needs anything but micro; `micro)` always.
- **Adaptive slots over always-on segments:** v2 replaced always-on `cache_stats` with the `alerts_slot` + `info_slot` architecture. Slots emit only the first priority match (or nothing). This keeps the line cleaner when nothing interesting is happening and surfaces only actionable state when it is.
- **Benchmark thresholds are regression guards, not targets.** The `--bench` threshold (100ms macOS / 60ms Linux) reflects the current hot path: jq fixed cost (~25-30ms) + three segment passes in zen + git cache refresh. If you change those thresholds, do it deliberately after a perf pass — the numbers exist to catch regressions, not to justify current overhead.

## JSON Input Schema

Claude Code sends JSON via stdin. Key fields extracted by `main.sh`:

```
.cwd (fallback .workspace.current_dir)        -> sl_cwd
.model.id                                     -> sl_model_id
.model.display_name                           -> sl_model_name
.context_window.used_percentage               -> sl_used_pct
.context_window.context_window_size           -> sl_ctx_size
.context_window.current_usage.input_tokens    -> sl_input_tokens
.context_window.current_usage.output_tokens   -> sl_output_tokens
.context_window.current_usage.cache_creation_input_tokens -> sl_cache_create_tokens
.context_window.current_usage.cache_read_input_tokens     -> sl_cache_read_tokens
.context_window.total_input_tokens            -> sl_total_input_tokens
.context_window.total_output_tokens           -> sl_total_output_tokens
.cost.total_duration_ms                       -> sl_duration_ms
.cost.total_api_duration_ms                   -> sl_api_duration_ms
.cost.total_lines_added                       -> sl_lines_added
.cost.total_lines_removed                     -> sl_lines_removed
.worktree.name                                -> sl_worktree_name
.agent.name                                   -> sl_agent_name
.exceeds_200k_tokens                          -> sl_exceeds_200k
.rate_limits.five_hour.used_percentage        -> sl_rate_5h_pct
.rate_limits.five_hour.resets_at              -> sl_rate_5h_reset_ts
.rate_limits.seven_day.used_percentage        -> sl_rate_7d_pct
.rate_limits.seven_day.resets_at              -> sl_rate_7d_reset_ts
.output_style.name                            -> sl_output_style
.session_name                                 -> sl_session_name
(.workspace.added_dirs | length)              -> sl_added_dirs_count
.workspace.project_dir (fallback .cwd)        -> sl_project_dir
```

All fields are optional. Missing fields default to empty strings (or `0` for `sl_added_dirs_count`). Segments skip rendering when their required inputs are absent.
