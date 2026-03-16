# CLAUDE.md

This file provides guidance to Claude Code and other AI assistants when working with this codebase. It also serves as architecture documentation for human contributors.

## Project Overview

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) built entirely in POSIX `sh`. It receives JSON via stdin, parses it with `jq`, and outputs ANSI-colored Powerline-style rows to the terminal. The layout adapts to terminal width across three tiers (full, compact, micro).

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
1. Sources `theme.sh` (which loads theme file + `derive.sh`)
2. Sources `lib.sh` (rendering engine)
3. Detects terminal width tier (`COLUMNS`)
4. Extracts JSON fields via single `jq` call
5. Sources all `segments/*.sh` (defines functions, no execution)
6. Calls `render_row()` for each row group

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
| `test/fixtures/*.json` | JSON scenario payloads: minimal, mid, full, critical |

### Three-Tier Adaptive Layout

Determined by `$COLUMNS` at runtime:

| Tier | Width | Rows | Content |
|------|-------|------|---------|
| Full | >= 120 | 2 | All 11 segments |
| Compact | 80-119 | 1 | Model + context + git + duration |
| Micro | < 80 | 1 | Abbreviated model + ctx% + project/branch pill |

### Segment Contract

Every segment is a **pure data function**. It sets `_seg_*` metadata variables and returns 0 (render) or 1 (skip). The `render_row()` orchestrator in `lib.sh` handles all rendering decisions.

**Metadata variables set by segments:**

| Variable | Values | Purpose |
|----------|--------|---------|
| `_seg_weight` | `primary`, `secondary`, `tertiary`, `recessed` | BG/FG treatment, separator style |
| `_seg_min_tier` | `full`, `compact`, `micro` | Minimum tier to display |
| `_seg_group` | `session`, `workspace` | Row assignment in full tier |
| `_seg_content` | plain text | Display text -- no ANSI escapes |
| `_seg_icon` | glyph var or empty | Nerd Font icon, orchestrator adds it |
| `_seg_bg` | 256-color number | Used by primary weight |
| `_seg_fg` | 256-color number | Used by primary; tertiary/recessed default to `C_DIM` if empty |
| `_seg_attrs` | `"bold"`, `"bold blink"`, or empty | Orchestrator wraps content in ANSI attrs |
| `_seg_detail` | text or empty | Rendered in dim after main content (e.g., git ahead/behind) |
| `_seg_link_url` | URL or empty | OSC 8 hyperlink target; orchestrator wraps `_seg_content` if set |

**Segments must NOT embed raw ANSI escapes in `_seg_content`.** Use `_seg_link_url` for OSC 8 hyperlinks -- the orchestrator wraps the content.

### Weight System and Separators

| Weight | Background | Separator to next | Typical use |
|--------|-----------|-------------------|-------------|
| Primary | Colored (per-segment) | Powerline arrow | Model, Context |
| Secondary | `C_MUTED_BG` | Thin pipe (same BG) | Project, Git |
| Tertiary | `C_MUTED_BG` | Thin pipe (same BG) | Burn-rate, Cache, Lines, Worktree |
| Recessed | `C_DIM_BG` | Thin pipe from muted | Duration (full tier only) |

Rule: Powerline arrow between **different** BGs. Thin pipe between **same** BGs.

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
| `SL_CAP_*` | Capability flags | `SL_CAP_NERD`, `SL_CAP_OSC8` |
| `GL_*` | Glyph variables | `GL_POWERLINE`, `GL_BRANCH` |
| `sl_*` | Runtime state from JSON or git cache | `sl_model_id`, `sl_branch` |
| `_seg_*` | Segment metadata (reset per segment) | `_seg_weight`, `_seg_content` |
| `_sl_*` | Session-scoped internal vars | `_sl_tier`, `_sl_cols` |
| `_xx_*` | Function-local vars (prefixed by function) | `_es_bg`, `_rr_icon`, `_cx_pct` |

### Segment Registration Order

Defined in `main.sh` as `SL_SEGMENTS`. Order = left-to-right render position:

```
segment_model segment_agent segment_context
segment_burn_rate segment_cache_stats
segment_micro_location
segment_project segment_git segment_lines
segment_worktree segment_duration
```

### Git State Variables

Set by `cache.sh` via `cache_refresh`. Available to segments:

`sl_branch`, `sl_is_detached`, `sl_is_dirty`, `sl_ahead`, `sl_behind`, `sl_stash_count`, `sl_github_base_url`

## Coding Conventions

- **POSIX sh only.** No bashisms (`[[ ]]`, arrays, `local`, process substitution). Test with `sh -n`.
- **No ANSI in segments.** Segments set `_seg_content` as plain text. The orchestrator handles all color/formatting.
- **Prefix all local variables** with `_xx_` where `xx` is a 2-3 letter function abbreviation to avoid collisions. POSIX sh has no `local` keyword, so all variables are global -- prefixing prevents accidental overwrites.
- **Use `${VAR:-default}` pattern** in derive.sh so themes can override any token.
- **`set -f`** is active in main.sh (globbing disabled). Temporarily re-enable with `set +f` if needed.
- Use `$(( ))` for arithmetic, `2>/dev/null` to suppress errors on non-numeric input.
- **Cache file security:** String values written to cache files must use single-quote escaping to prevent shell injection when the cache is sourced. Numeric values use `printf '%d'` which sanitizes to digits.

## Testing

```sh
# Run a scenario (minimal, mid, full, critical) across all 3 tiers:
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
3. Add `segment_my_segment` to `SL_SEGMENTS` in `main.sh` at the desired position
4. Run `sh -n lib/segments/my-segment.sh` to verify syntax
5. Run `sh test/run.sh --scenario full` to verify rendering

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

## JSON Input Schema

Claude Code sends JSON via stdin. Key fields extracted by `main.sh`:

```
.cwd                                          -> sl_cwd
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
.cost.total_lines_added                       -> sl_lines_added
.cost.total_lines_removed                     -> sl_lines_removed
.worktree.name                                -> sl_worktree_name
.agent.name                                   -> sl_agent_name
.exceeds_200k_tokens                          -> sl_exceeds_200k
```
