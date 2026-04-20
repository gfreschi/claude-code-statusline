# claude-code-statusline v2.0 Design

- Status: draft (pending user review)
- Date: 2026-04-17
- Scope: single v2.0 release encompassing all decisions from the brainstorming round
- Supersedes: current 2-row full-tier layout (kept as the default; zen 3-row is opt-in)

---

## 1. Motivation

The current statusline (v1) packs 11 segments into 2 rows and does this well, but three product signals drive the v2 redesign:

1. **Claude Code's JSON payload has grown**. The latest schema exposes `rate_limits.{five_hour,seven_day}`, `output_style.name`, `session_name`, `workspace.added_dirs`, `cost.total_api_duration_ms`, and `workspace.project_dir`. None of these are surfaced today.
2. **Rate-limit visibility is the single most-requested power-user feature** across the ecosystem (vfmatzkin, cc-statusline, ccstatusline, claude-powerline). The 5h / 7d windows determine whether a user can keep working and currently there is no signal at all in v1.
3. **The "adaptive state" ecosystem has matured** - other statuslines surface conflict state, skill activity, subdir drift, and ambient info in different ways. v2 introduces a structured adaptive-slot architecture that lets us absorb these opportunistically without bloating the default line.

The redesign also retires one weak signal (always-on cache-hit ratio) and introduces a fourth tier, `zen`, which is an opt-in 3-row heavy-top layout for users who want maximum information density on wide terminals.

---

## 2. Scope

### In scope for v2.0

1. New `segment_rate_limit` (Ember preset with 4 configurable visual variants)
2. `segment_burn_rate` upgrade: braille sparkline trajectory tail
3. `segment_cache_stats` retirement (reappears as conditional alert)
4. New `segment_alerts_slot` (Row 1 / session-row conditional alert rotation)
5. New `segment_info_slot` (Row 3 / workspace-row informational rotation)
6. `segment_git` upgrades: staged / unstaged / untracked split, conflicts override, fork badge
7. `segment_duration` upgrade: API-time vs wall-time split
8. `segment_context` upgrade: V1 configurable gauge style (dots / blocks / braille / pips)
9. New capsule cap-shape option (V3) via `CLAUDE_STATUSLINE_CAP_STYLE`
10. New zen layout (3-row heavy-top) activated via `CLAUDE_STATUSLINE_LAYOUT=zen` on terminals >= 140 cols
11. Config system: per-segment enable/disable list, config file support, minimalist mode
12. Fresh JSON field extraction: rate limits, output style, session name, added dirs, API duration, project dir
13. New derived signals: subdir drift (cwd vs project_dir), clock fallback

### Explicitly out of scope for v2.0

- Thinking-effort indicator, last-used-skill, turns-counter, time-since-last-user-idle timer (all require transcript-file parsing; deferred to a future release)
- Session cost surfacing in USD (user preference; dollars not shown)
- Token velocity as a separate segment (`cost.total_cost_usd` exists but user skipped)
- PR-link integration (requires `gh` CLI dependency; not worth the coupling for v2.0)
- Fish-style path abbreviation and "remaining-mode" for context (user skipped)
- Claude Code version tag (Claude Code surfaces this natively; no value duplicating)
- Update-available notification (Claude Code surfaces this natively)

### Post-2.0 feasibility notes (2026-04-20 probe)

A live capture of Claude Code's stdin JSON revealed additional fields that were
not present in the fixtures used during v2.0 design. These unlock the transcript-
derived features above, so the "deferred" list is now "scoped but unbuilt":

| Field | Availability | Unlocks |
| --- | --- | --- |
| `transcript_path` | present, JSONL file path | turns-counter, last-skill, idle-timer, thinking-effort |
| `cost.total_cost_usd` | present (float) | session-cost segment |
| `session_id` | present (UUID) | grouping/multi-session identification |
| `version` | present (e.g. `2.1.114`) | version badge (low value; CC surfaces it) |
| `vim.mode` | present (string) | vim-mode badge for terminal users |

Transcript events include `type` tags (`user`, `assistant`, `attachment`,
`system`, ...) with assistant content blocks for `tool_use`, `thinking`, and
`text`. Tool-use blocks carry `.name` (e.g. `Skill`, `Bash`, `Edit`), making
last-skill trivial. Turns-counter reduces to counting `.type=="user"` events.
Idle-timer is a delta against the newest event's `.timestamp`.

Building these would add transcript-parse cost per render. Mitigations: cache
the last parse keyed on transcript-file mtime, or read only the tail via
`tail -n ...`. A dedicated segment is worth doing only if the user opts in --
the current status line is free of transcript I/O.

- Flex right-alignment in the render engine (rejected; would require a second
  pass for the render pipeline with no clear user benefit given the current
  multi-row layout). A prototype right-slot renderer was built and removed
  during post-2.0 review; the classic "left-justified row with end cap"
  visual is the intended identity.

### Preserved behavior

- The classic 2-row full-tier layout remains the default. Existing users who upgrade without changing env vars should see no disruptive change beyond:
  - `rate_limit` appearing on the session row (new)
  - `cache_stats` no longer always-on (removed; alerts only)
  - `git` gaining finer sub-counts
  - `duration` gaining the API-time split suffix
- All existing themes work unchanged. No palette variables added.

---

## 3. Architecture changes

### 3.1 Row groups: `session`, `workspace`, new `ambient`

v1 has two groups: `session` and `workspace`. v2 introduces `ambient` as a third group for the zen layout's Row 3. `ambient` segments only render when the active layout is `zen`. In `classic` (default) layout, ambient segments fold back into one of the two existing rows per their fallback group assignment.

Each segment now declares:

- `_seg_group` (primary group: `session`, `workspace`, or `ambient`)
- `_seg_group_fallback` (optional; which group to use when layout is `classic` and primary group is `ambient`)

The render orchestrator (`render_row`) accepts a group argument as today, and applies the fallback logic at the start of iteration.

### 3.2 Layout modes

```
classic (default)       zen (opt-in, >= 140 cols)
-----------------        ------------------------
session                  signals  (primary-weight heavy)
workspace                workspace
                         ambient  (recessed-weight)
```

- `CLAUDE_STATUSLINE_LAYOUT=classic` (default): 2 rows on full tier, existing behavior.
- `CLAUDE_STATUSLINE_LAYOUT=zen`: 3 rows on full tier (if width >= 140), otherwise transparently falls back to `classic` 2-row. The fallback check happens in `main.sh` after tier detection.

### 3.3 Tier adaptation

| Tier    | Width       | Rows | Layout behavior                                              |
|---------|-------------|------|--------------------------------------------------------------|
| zen     | >= 140      | 3    | Requires opt-in via `CLAUDE_STATUSLINE_LAYOUT=zen`. signals / workspace / ambient. |
| full    | >= 120      | 2    | Default. session / workspace.                                |
| compact | 80-119      | 1    | Group gate disabled; essential segments only.                |
| micro   | < 80        | 1    | Abbreviated; 4 segments max.                                 |

Width check for zen happens in `main.sh`:

```sh
_sl_layout="${CLAUDE_STATUSLINE_LAYOUT:-classic}"
if [ "$_sl_layout" = "zen" ] && [ "$_sl_cols" -ge 140 ]; then
  _sl_tier="zen"
elif [ "$_sl_cols" -ge 120 ]; then
  _sl_tier="full"
elif [ "$_sl_cols" -ge 80 ]; then
  _sl_tier="compact"
else
  _sl_tier="micro"
fi
```

Segment `_seg_min_tier` gains a fourth value: `zen` (segment only renders in zen mode). Existing values (`full`, `compact`, `micro`) remain.

### 3.4 Weight system: no new weights, but Row 3 enforces recessed

The four existing weights (`primary`, `secondary`, `tertiary`, `recessed`) cover every rendering need. Zen mode's visual separation is achieved by:

- Row 1 (signals): allows `primary` and `tertiary`
- Row 2 (workspace): allows `secondary` and `tertiary`
- Row 3 (ambient): only `recessed`

The orchestrator enforces this by downgrading `_seg_weight` to `recessed` if an ambient-group segment declares otherwise. This is a hard rule, not negotiable per-segment.

### 3.5 Segment list change

v2 adds two new segments and retires one. The new `SL_SEGMENTS` order in `main.sh`:

```
segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_alerts_slot \
  segment_micro_location \
  segment_project segment_git segment_info_slot \
  segment_rate_limit_7d_stable \
  segment_lines segment_worktree segment_duration
```

Removed: `segment_cache_stats` (file retained for reference then deleted after the migration).

The two rate-limit segments are distinct by design:

- `segment_rate_limit`: renders the 5h window on Row 1 (signals / session). Includes inline 7d when 7d >= 50% and layout is `classic`; omits 7d when layout is `zen` (because 7d lives on Row 3 in zen).
- `segment_rate_limit_7d_stable`: renders only when layout is `zen` AND 7d used% < 70%. Group `ambient`, weight `recessed`. Above 70%, this segment returns non-zero and `segment_alerts_slot` picks up the warning instead.

---

## 4. New segments

### 4.1 `segment_rate_limit`

- File: `lib/segments/rate-limit.sh`
- Group: `session`
- Weight: `tertiary` normally; promotes to `primary` on critical state (>= 85% used or rate-burn projected)
- Min tier: `micro`
- Reads: `sl_rate_5h_pct`, `sl_rate_5h_reset_ts`, `sl_rate_7d_pct`, `sl_rate_7d_reset_ts`

**Default visual (Ember preset):** time-led battery glyph with adaptive detail.

New glyphs required (add to `detect_capabilities` in `lib/render.sh`):

- `GL_BATT_FULL` (Nerd Font: `nf-md-battery` or equivalent, ~80-100% state)
- `GL_BATT_MID`  (Nerd Font: `nf-md-battery_60` or equivalent, ~30-79% state)
- `GL_BATT_LOW`  (Nerd Font: `nf-md-battery_10` or equivalent, <30% state)
- `GL_FORK`      (Nerd Font: `nf-dev-git_fork` or equivalent; for the git fork badge)

ASCII fallbacks: `GL_BATT_FULL='FULL'`, `GL_BATT_MID='MID'`, `GL_BATT_LOW='LOW'`, `GL_FORK='fork'`.

| State              | Renders                                                                        |
|--------------------|--------------------------------------------------------------------------------|
| Healthy (< 50%)    | `GL_BATT_FULL 4h12m left . 78%`                                                |
| Warming (50-84%)   | `GL_BATT_MID 1h48m left . 35% . 7d 52%` (7d inline only when layout=classic)   |
| Critical (>= 85%)  | `GL_BATT_LOW burns in 12m UP . 8% left . 24m reset . 7d 74%` (7d inline only when classic) |

**Configurable via `CLAUDE_STATUSLINE_RATE_STYLE`:**

- `ember` (default): time-led battery glyph as above
- `bar`: fusion bar (length = time elapsed, color = pace state). `5h BAR 65% . 1h48m left`
- `pill`: twin pills - 5h + 7d always parallel. `5h 35% . 1h48m | 7d 52% . 3d`
- `minimal`: time + percent only. `1h48m . 35%`

**Pace arrow** appears only when `(used% / elapsed%) > 1.0` in critical state. Shows as `UP Xm` where X is the projected minutes to 100% at current burn rate.

**Tier behavior:**

- zen Row 1: full ember rendering with 7d inline when warming; 7d promoted here from Row 3 when 7d >= 70%
- full: same as zen but no escalation (7d would not be on Row 3 in classic)
- compact: drops 7d, drops inline detail. `HALF-BATTERY 1h48m . 35%`
- micro: `HALF-BATTERY 1h48m`

### 4.2 `segment_alerts_slot`

- File: `lib/segments/alerts-slot.sh`
- Group: `session`
- Weight: `tertiary`
- Min tier: `full` (does not appear on compact or micro)

Rotates through conditional alerts by priority and renders the single highest-priority match.

**Priority order:**

1. `cache-poor` (cache hit ratio < 70% and `cache_read_tokens > 0`): renders `GL_CACHE cache 43%`
2. `added-dirs` (`workspace.added_dirs` array non-empty): renders `+N dirs`
3. `7d-warning` (`rate_limits.seven_day.used_percentage >= 70` AND layout is `zen`): renders `GL_WARN 7d 74%`. In `classic` layout the 7d-warning does not fire here because 7d is always inline in `segment_rate_limit` when 7d >= 50%; this rule only applies to zen mode where 7d lives on Row 3 and needs a promotion path.

If nothing matches, the segment returns non-zero and is skipped (no space consumed).

### 4.3 `segment_info_slot`

- File: `lib/segments/info-slot.sh`
- Group: `ambient` (falls back to `workspace` in classic layout)
- Weight: `recessed` (enforced)
- Min tier: `full`

Rotates through informational items by priority; always tries to render at least one item (clock as the always-true fallback).

**Priority order:**

1. `output-style` (`.output_style.name` is present and not `"default"`): renders `. <StyleName>`
2. `subdir` (`sl_cwd != sl_project_dir` and cwd is a descendant): renders `> <relative-path>` (max 20 chars; truncate with ellipsis from the left: `>...auth/routes.ts`)
3. `session-name` (`.session_name` is present): renders `@<name>`
4. `clock` (always true): renders `CLOCK-GLYPH HH:MM`

### 4.4 New JSON field extraction in `main.sh`

The single `jq` call in `main.sh` gains these extractions:

```
sl_rate_5h_pct, sl_rate_5h_reset_ts
sl_rate_7d_pct, sl_rate_7d_reset_ts
sl_output_style
sl_session_name
sl_added_dirs_count (from `.workspace.added_dirs | length`)
sl_api_duration_ms (from `.cost.total_api_duration_ms`)
sl_project_dir (from `.workspace.project_dir`, falling back to `.cwd`)
```

All are guarded by `// empty` and `| tostring | @sh` as today. No additional `jq` invocations.

---

## 5. Upgraded segments

### 5.1 `segment_burn_rate` gains a sparkline tail

- Adds a braille sparkline of the last 8 render samples of tokens-per-minute.
- State: a small ring buffer persisted under `$TMPDIR/claude-statusline-cache/<user>/burn-history` (reusing the existing cache pattern from `lib/cache.sh`).
- Braille glyphs: `BRL1 BRL2 BRL3 BRL4 BRL5 BRL6 BRL7 BRL8` mapped to the range min-to-max observed in the buffer.
- Color: follows current burn intensity (green / gold / red) via the `C_BURN_*` tokens.
- Size: 8 chars (fixed).
- Disabled automatically on micro tier (sparkline glyph falls back to `...` if no unicode, and is skipped entirely at micro).

Cache-file contract:

- Format: single line, 8 comma-separated integers (oldest-first).
- Writer: `segment_burn_rate` appends the current sample and shifts.
- Reader: same segment on next render reads the buffer.
- TTL: 5s (same as existing cache).
- Security: `printf '%d'` sanitizes to digits before write. No eval.

### 5.2 `segment_git` upgrades

Three new behaviors, all driven off the existing 5s git cache:

- **Staged / unstaged / untracked split.** Replaces the single dirty dot with `+A  -B  ?C` where any of A/B/C may be omitted when zero. Reuses `git status --porcelain`.
- **Conflicts override.** When `.git/MERGE_HEAD` or `.git/rebase-merge/` exists, the branch content is replaced by `! <OPERATION> <step>/<total>` (e.g. `! REBASING 2/5`). Computed from `.git/rebase-merge/msgnum` and `.git/rebase-merge/end`, or `.git/rebase-apply/next` and `.git/rebase-apply/last`. When MERGE_HEAD exists without rebase files, shows `! MERGING`.
- **Fork badge.** When the `origin` remote URL differs from the `upstream` remote URL (and both exist), a small `FORK-GLYPH fork` suffix appears after ahead/behind.

All three new behaviors cache their results alongside existing git cache fields.

### 5.3 `segment_duration` gains API-time split

- Adds ` (api Nm)` as detail when `sl_api_duration_ms >= 60000` and API < wall time.
- When `api_pct < 15%` after 20+ minutes, the detail color escalates to `C_DUR_MED` as a nudge.
- Shown only on full / zen tier (not compact, which retains the plain form).

### 5.4 `segment_context` gains V1 gauge styles

- Reads `CLAUDE_STATUSLINE_CTX_GAUGE` (values: `dots` [default], `blocks`, `braille`, `pips`).
- Gauge rendering delegated to a small helper `ctx_gauge_render()` in `lib/render.sh`.
- Glyph tables added to capability detection:
  - `dots`: existing `GL_DOT_FILLED` / `GL_DOT_EMPTY`
  - `blocks`: `GL_BLK_FILLED='\u2593'` (medium shade) / `GL_BLK_EMPTY='\u2591'` (light shade)
  - `braille`: `GL_BRL_0`..`GL_BRL_8` (BRL1-BRL8 sequence from sparkline)
  - `pips`: `GL_PIP_FILLED='\u00b7'` / `GL_PIP_EMPTY=' '`
- Width preserved at 5 cells regardless of style (cells are visually uniform).
- ASCII fallback unchanged (uses `*` / `-`).

---

## 6. Config system

### 6.1 Environment variables (existing + new)

| Variable                             | Default             | Purpose                                                        |
|--------------------------------------|---------------------|----------------------------------------------------------------|
| `CLAUDE_STATUSLINE_THEME`            | `catppuccin-mocha`  | existing                                                       |
| `CLAUDE_STATUSLINE_NERD_FONT`        | `1`                 | existing                                                       |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`    | `95`                | existing                                                       |
| `CLAUDE_STATUSLINE_LAYOUT`           | `classic`           | `classic` or `zen`                                             |
| `CLAUDE_STATUSLINE_RATE_STYLE`       | `ember`             | `ember`, `bar`, `pill`, `minimal`                              |
| `CLAUDE_STATUSLINE_CTX_GAUGE`        | `dots`              | `dots`, `blocks`, `braille`, `pips`                            |
| `CLAUDE_STATUSLINE_CAP_STYLE`        | `powerline`         | `powerline`, `capsule`                                         |
| `CLAUDE_STATUSLINE_SEGMENTS`         | (full default list) | Comma-separated segment-name list; overrides `SL_SEGMENTS`     |
| `CLAUDE_STATUSLINE_MINIMAL`          | `0`                 | When `1`, hides all icons and reduces labels to bare values    |
| `CLAUDE_STATUSLINE_CONFIG_FILE`      | `~/.config/claude-statusline/config.sh` | Path override; sourced at startup if present   |

### 6.2 Config file

`main.sh` sources the config file at startup before reading other env vars, so values inside the file can set any `CLAUDE_STATUSLINE_*` variable:

```sh
# Near the top of main.sh, after SL_DIR resolution
_sl_cfg="${CLAUDE_STATUSLINE_CONFIG_FILE:-$HOME/.config/claude-statusline/config.sh}"
[ -r "$_sl_cfg" ] && . "$_sl_cfg"
```

Example file content:

```sh
# ~/.config/claude-statusline/config.sh
CLAUDE_STATUSLINE_THEME=dracula
CLAUDE_STATUSLINE_LAYOUT=zen
CLAUDE_STATUSLINE_RATE_STYLE=bar
CLAUDE_STATUSLINE_SEGMENTS="model,context,rate_limit,project,git,duration"
```

Security note: the config file is sourced. Documentation must call out that it runs as the user's shell and should only contain variable assignments.

### 6.3 Per-segment enable/disable

`CLAUDE_STATUSLINE_SEGMENTS` is a comma-separated list of segment function basenames (without the `segment_` prefix). When set, overrides the default `SL_SEGMENTS`. Unknown names are silently ignored (no error to stderr; that would pollute the status line output).

### 6.4 Minimalist mode

- `CLAUDE_STATUSLINE_MINIMAL=1` triggers these overrides in the orchestrator and segments:
  - No icons at all (orchestrator skips the `_rr_icon` prepend)
  - The following segment-specific labels are stripped and only the values render:
    - `rate_limit`: drops `5h`, `7d`, `left`, `reset`
    - `burn_rate`: drops `k/m` suffix (value becomes raw digits)
    - `alerts_slot` / `info_slot`: drop label prefixes (`cache`, `@`, `.`, `>`)
    - `duration`: drops `(api Nm)` suffix entirely
    - `git`: keeps `+A -B ?C` and ahead/behind markers; drops `fork` text (keeps the glyph when nerd font is on, or nothing when minimal + no-nerd)
  - Colors are preserved; only glyphs and textual labels are stripped. State still conveyed via color escalation.
- Useful for SSH remote sessions, terminals without Nerd Font, or screenshot workflows that want a flatter aesthetic.

---

## 7. Zen layout specification

### 7.1 Row assignments

| Row | Name      | Group     | Weight(s) allowed         | Typical chars | Segments                                                                   |
|-----|-----------|-----------|---------------------------|---------------|----------------------------------------------------------------------------|
| 1   | signals   | session   | primary, tertiary         | ~100-120      | model, agent (conditional), context, rate_limit, burn_rate, alerts_slot    |
| 2   | workspace | workspace | secondary, tertiary       | ~70-90        | project, git, lines, duration                                              |
| 3   | ambient   | ambient   | recessed only (enforced)  | ~35-55        | rate_limit_7d_stable, info_slot                                            |

### 7.2 Width hierarchy rule

Row 1 >= Row 2 >= Row 3 in typical state. Enforced informally via:

- Segment `_seg_min_tier='zen'` for items that only appear on Row 3
- `alerts_slot` min_tier set to `full` (Row 1 budget is elastic)
- `info_slot` min_tier set to `zen` in terms of default group; falls back to workspace in classic

### 7.3 7d rate-limit escalation

When zen layout is active:

- `segment_rate_limit_7d_stable` (dedicated segment) renders on Row 3 (ambient, recessed) showing `7d 52% . 3d left` when 7d used% < 70%.
- At 7d used% >= 70%, `segment_rate_limit_7d_stable` returns non-zero (nothing on Row 3) and `segment_alerts_slot` picks up the `7d-warning` alert on Row 1. The spatial movement from Row 3 to Row 1 IS the signal - no visual flash needed.
- `segment_rate_limit` (Row 1) in zen mode never shows 7d inline, because 7d has its own home.
- In classic layout, `segment_rate_limit_7d_stable` returns non-zero (self-gate on `$_sl_layout != "zen"`) and `segment_rate_limit` shows 7d inline when warming, matching the classic-tier spec. The segment remains registered in `SL_SEGMENTS` globally; its function body is responsible for the layout-gate check.

### 7.4 Cap style

- `powerline` (default): existing `GL_POWERLINE` rendering (triangular arrow between different BGs, thin pipe on same BG).
- `capsule`: left cap `U+E0B6`, right cap `U+E0B4`. Emitted at the first segment of each row (left cap) and after `emit_end` (right cap). Thin pipe between same-BG segments stays the same.

Cap glyph table in `detect_capabilities`:

```sh
if [ "$SL_CAP_NERD" -eq 1 ]; then
  case "${CLAUDE_STATUSLINE_CAP_STYLE:-powerline}" in
    capsule)
      GL_CAP_LEFT='\ue0b6'
      GL_CAP_RIGHT='\ue0b4'
      GL_POWERLINE='\ue0b0'  # still used for inter-segment transitions
      ;;
    *)
      GL_CAP_LEFT=''
      GL_CAP_RIGHT=''
      GL_POWERLINE='\ue0b0'
      ;;
  esac
fi
```

Capsule style adds a single-glyph cap at each row's start and end; the inter-segment separators are unchanged. This gives the "pill" look without a full rewrite of the transition logic.

---

## 8. Testing plan

### 8.1 Fixtures

Add 4 new JSON fixtures to `test/fixtures/`:

- `rate-healthy.json`: 5h 22%, 7d 18%, healthy context, no alerts
- `rate-warming.json`: 5h 65%, 7d 52%, warming context, output-style set, subdir active
- `rate-critical.json`: 5h 92% with projected burn, 7d 74%, context 96%, cache 43%, rebase in progress, session-name set
- `zen-full.json`: full cwd drift, session-name, added_dirs, all ambient items firing

### 8.2 Test cases

- All 4 new fixtures x {classic, zen} layouts x {full, compact, micro} tiers x 4 themes = 96 snapshots under `test/run.sh --check`
- Rate-limit preset iteration: same fixture rendered with `CLAUDE_STATUSLINE_RATE_STYLE=ember,bar,pill,minimal` = 4 snapshots each
- Context gauge iteration: same fixture rendered with `CLAUDE_STATUSLINE_CTX_GAUGE=dots,blocks,braille,pips` = 4 snapshots
- Cap style iteration: `CLAUDE_STATUSLINE_CAP_STYLE=powerline,capsule` = 2 snapshots
- Config file loading: verify that a `config.sh` overrides env vars
- `CLAUDE_STATUSLINE_SEGMENTS` override: verify the segment filter works
- `CLAUDE_STATUSLINE_MINIMAL=1`: verify icon / label stripping across all tiers

### 8.3 Shell coverage

All existing `--shell` variants (`sh`, `dash`, `bash`, `zsh`) continue to be covered by `test/run.sh --check --shell <name>`.

### 8.4 Performance guardrail

- Add a simple `time` benchmark in `test/run.sh`: the zen-full fixture must render in under 50ms on macOS and 30ms on Linux using the default shell. If it exceeds, the test fails.
- The single-`jq` invocation constraint is preserved. No new subshells in the hot path.

---

## 9. Migration and backwards compatibility

- No themes change. No palette variables added.
- The default rendering (no env vars set) matches v1 as closely as possible:
  - Rate-limit segment appears on session row (new; cannot avoid without feature parity loss)
  - Cache-stats no longer always-on (removed; the user-visible cache signal survives via alerts_slot at < 70%)
  - Git segment slightly richer in content, same visual weight
  - Duration adds `(api Nm)` suffix; wall-time format unchanged
- Env vars are strictly additive. Unset env vars yield the v1-equivalent behavior except for the two items above.
- THEMES.md, README.md, CONTRIBUTING.md, CLAUDE.md need updating (see section 11).
- The install script keeps its current pattern; no breaking interface changes.
- Uninstall behavior is unchanged.

---

## 10. Security and performance considerations

- **Config file sourcing.** Documented that the file is sourced as shell; users should audit contents. Only `CLAUDE_STATUSLINE_*` variable assignments recommended.
- **Sparkline cache file.** Stored under `$TMPDIR/claude-statusline-cache/<user>/` with 0700 directory and 0600 file modes (same as existing git cache). Values are written via `printf '%d'` to sanitize to digits only; never eval'd.
- **No new subshells in hot path.** The single `jq` call in `main.sh` grows; it does not become multiple calls.
- **Git extra-file checks** (`MERGE_HEAD`, `rebase-merge/`, `rebase-apply/`) are `-f` / `-d` tests, cheap and already protected by the 5s git cache TTL.
- **`set -f`** remains active. Globbing only re-enabled for the segments directory iteration.
- **No set -e.** Preserved per design invariant: the status line degrades gracefully.

---

## 11. Documentation updates

- `README.md`: add a "Zen mode" subsection, update the "What You Get" table for the added rate-limit + removed cache-stats, update the themes screenshot command (no behavior change there), add an "Install / config file" example.
- `THEMES.md`: no change. Palette untouched.
- `CONTRIBUTING.md`: document the new `_seg_group_fallback` and `ambient` group; describe the new segment contract extensions (e.g. `_seg_min_tier='zen'`).
- `CLAUDE.md`: update the "File Responsibilities", "Three-Tier Adaptive Layout" (now four tiers), "Segment Contract" (added fallback field), "Variable Naming Conventions" (sparkline cache file, `SL_LAYOUT` runtime var), "Segment Registration Order", "Adding a New Segment" (updated template to include group fallback + layout), "JSON Input Schema" (add new fields).
- New file: `CONFIG.md`. Comprehensive reference for every env var and the config-file pattern with examples.

---

## 12. Implementation sequencing (within v2.0)

Although Option A is a single release, the implementation still benefits from a predictable internal sequence:

1. **Foundation:** config file loading, `CLAUDE_STATUSLINE_LAYOUT` tier, `CLAUDE_STATUSLINE_SEGMENTS` override, `CLAUDE_STATUSLINE_MINIMAL` mode. New JSON field extraction in `main.sh`. New cache helpers for sparkline ring buffer. `CONFIG.md`.
2. **Rate-limit segment:** `segment_rate_limit` with all four presets. 5h escalation logic. Tests.
3. **Retire cache-stats + introduce alerts_slot and info_slot:** remove `cache-stats.sh`; add the two slot segments with the priority-rotation logic. Tests.
4. **Git upgrades:** staged/unstaged/untracked split; conflicts override; fork badge. Cache schema extension.
5. **Duration upgrade:** API-time suffix. Escalation color for low-api ratio.
6. **Context gauge styles (V1):** glyph tables, `ctx_gauge_render` helper, all 4 styles.
7. **Cap shapes (V3):** capsule glyphs wired into the row start and row end.
8. **Zen 3-row layout:** new group `ambient`, row-3 renderer, 7d escalation logic, width-check for >= 140.
9. **Burn-rate sparkline:** ring buffer, braille rendering, tests.
10. **Documentation:** README / CONTRIBUTING / CLAUDE.md / new CONFIG.md.
11. **Snapshot tests + performance benchmarks.**

This sequence lets intermediate commits be individually testable. Every step after (1) and (2) is independently shippable in principle.

---

## 13. Open risks

- **Width overflow on 120-col terminals in v2 full tier.** The new session row with rate-limit + burn-rate + alerts-slot adds ~30 chars over v1. Critical states can exceed 120. Mitigation: alerts_slot `min_tier=full` plus the single-item rotation; and sparkline (8 chars) is omitted below certain widths via a width-remaining check.
- **Braille-glyph rendering inconsistency across terminals.** Kitty and iTerm render braille well; some older terminals (Apple Terminal with legacy fonts) may not. Mitigation: `CLAUDE_STATUSLINE_CTX_GAUGE=dots` stays default and braille is opt-in.
- **Capsule glyphs are PUA.** `U+E0B6` / `U+E0B4` require Nerd Font. Falls back to plain character gracefully when Nerd Font is disabled (same pattern as existing powerline arrow).
- **Transcript-derived signals are deferred.** Users who want thinking-effort or last-used-skill badges need to wait. Documented in section 2.
- **Config file sourcing trust boundary.** Users running untrusted config files execute arbitrary shell. Documentation must call this out prominently.

---

## 14. Glossary

- **Classic layout:** the existing 2-row full-tier layout. Default.
- **Zen layout:** the new opt-in 3-row heavy-top layout. Requires `CLAUDE_STATUSLINE_LAYOUT=zen` and width >= 140.
- **Signals row:** Row 1 in zen mode. High-value dynamic content.
- **Ambient row:** Row 3 in zen mode. Recessed-weight supplemental info.
- **Alerts-slot:** Row 1 segment that rotates through conditional alerts (cache-poor, added-dirs, 7d-warning).
- **Info-slot:** Row 3 segment (or workspace-row in classic) that rotates through informational items (output-style, subdir, session-name, clock).
- **Ember preset:** the default `segment_rate_limit` visual style. Time-led with battery glyph and progressive disclosure.
- **Fusion bar:** the `bar` preset for `segment_rate_limit`. Bar length = time elapsed, color = pace state.
- **Pace arrow:** `UP Xm` indicator showing projected minutes to 100% at current burn rate. Silent unless overrunning.
- **Pill preset / minimal preset:** alternative `segment_rate_limit` visuals.
