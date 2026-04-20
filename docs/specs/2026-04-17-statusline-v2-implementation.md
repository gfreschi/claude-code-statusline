# claude-code-statusline v2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v2.0 of the status line with rate-limit visibility, adaptive slots, zen 3-row layout, config system, git/duration/context/burn upgrades, and V1/V3 visual variants — all as a single release on branch `feat/v2-statusline-enhancements`.

**Architecture:** POSIX `sh` orchestrator that receives JSON on stdin, extracts fields via one `jq` call, sources segment files that set `_seg_*` metadata, and renders rows through a weight-based orchestrator. v2 adds a fourth tier (`zen`), a third row group (`ambient`), two "slot" segments that rotate through conditional content, a config-file loader, and an opt-in capsule cap-shape.

**Tech Stack:** POSIX `sh` (must work in `sh` / `dash` / `bash` / `zsh`), `jq`, 256-color terminal, Nerd Font (optional). No compiled dependencies, no new runtime requirements.

**Spec:** `docs/specs/2026-04-17-statusline-v2-enhancements-design.md`
**Baseline:** 48 passing tests on `main`. All work happens on `feat/v2-statusline-enhancements`.

---

## Consistency Plan (Contracts)

**Every subagent implementing any task MUST read this section first and treat it as ground truth.** If something below contradicts the spec, the spec wins — escalate to the human, do not freelance.

### C1. Environment variable naming + defaults

| Name                             | Default                                   | Accepted values                           |
|----------------------------------|-------------------------------------------|-------------------------------------------|
| `CLAUDE_STATUSLINE_THEME`        | `catppuccin-mocha`                        | any file in `lib/themes/` (without `.sh`) |
| `CLAUDE_STATUSLINE_NERD_FONT`    | `1`                                       | `0` / `1`                                 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`| `95`                                      | integer 50-99                             |
| `CLAUDE_STATUSLINE_LAYOUT`       | `classic`                                 | `classic` / `zen`                         |
| `CLAUDE_STATUSLINE_RATE_STYLE`   | `ember`                                   | `ember` / `bar` / `pill` / `minimal`      |
| `CLAUDE_STATUSLINE_CTX_GAUGE`    | `dots`                                    | `dots` / `blocks` / `braille` / `pips`    |
| `CLAUDE_STATUSLINE_CAP_STYLE`    | `powerline`                               | `powerline` / `capsule`                   |
| `CLAUDE_STATUSLINE_SEGMENTS`     | (unset; falls through to default list)    | comma-separated segment basenames         |
| `CLAUDE_STATUSLINE_MINIMAL`      | `0`                                       | `0` / `1`                                 |
| `CLAUDE_STATUSLINE_CONFIG_FILE`  | `$HOME/.config/claude-statusline/config.sh` | absolute path                           |

Validation rule: unknown values fall back to the default silently. No error messages to stdout (would pollute status line).

### C2. Segment function + file naming

- File name: `lib/segments/<kebab-name>.sh`
- Function name: `segment_<snake_name>`
- Example: `lib/segments/rate-limit-7d-stable.sh` defines `segment_rate_limit_7d_stable`

### C3. Segment metadata fields

Segments MUST set the following via `_seg_*` variables. Orchestrator reads after the segment function returns 0:

| Variable              | Values / type                                       | Meaning                                       |
|-----------------------|-----------------------------------------------------|-----------------------------------------------|
| `_seg_weight`         | `primary` / `secondary` / `tertiary` / `recessed`   | BG/FG pattern                                 |
| `_seg_min_tier`       | `zen` / `full` / `compact` / `micro`                | lowest tier that renders this segment         |
| `_seg_group`          | `session` / `workspace` / `ambient`                 | which row in multi-row tiers                  |
| `_seg_group_fallback` | `session` / `workspace` / empty                     | NEW: fallback group when layout != zen        |
| `_seg_content`        | plain text                                          | display text, no ANSI                         |
| `_seg_icon`           | `$GL_*` variable or empty                           | prepended by orchestrator                     |
| `_seg_bg`             | integer 0-255                                       | required for primary weight                   |
| `_seg_fg`             | integer 0-255 or empty                              | required for primary; defaults for others     |
| `_seg_attrs`          | `"bold"` / `"bold blink"` / empty                   | attribute wrappers                            |
| `_seg_detail`         | plain text or empty                                 | dim inline secondary info                     |
| `_seg_link_url`       | URL or empty                                        | OSC 8 wrap target                             |

**Hard rule:** Segments that set `_seg_group=ambient` and any `_seg_weight != recessed` are corrected by the orchestrator to `recessed`. The fallback field is honored only when `$_sl_layout = "classic"`.

### C4. New glyph variables (additions to `detect_capabilities` in `lib/render.sh`)

| Name               | Nerd Font (U+xxxx)      | ASCII fallback |
|--------------------|-------------------------|----------------|
| `GL_BATT_FULL`     | U+F240 (`nf-fa-battery_full`)            | `FULL`          |
| `GL_BATT_MID`      | U+F242 (`nf-fa-battery_half`)            | `MID`           |
| `GL_BATT_LOW`      | U+F244 (`nf-fa-battery_quarter`)         | `LOW`           |
| `GL_FORK`          | U+E725 fallback to `nf-dev-git_pull_request` | `fork`      |
| `GL_CAP_LEFT`      | U+E0B6                                   | `(`             |
| `GL_CAP_RIGHT`     | U+E0B4                                   | `)`             |
| `GL_BLK_FILLED`    | U+2593                                   | `*`             |
| `GL_BLK_EMPTY`     | U+2591                                   | `-`             |
| `GL_PIP_FILLED`    | U+00B7 (middle dot)                      | `*`             |
| `GL_PIP_EMPTY`     | ` ` (space)                              | ` `             |
| `GL_BRL_0`..`GL_BRL_8` | U+2800..U+28FF braille (9 buckets)   | `_=+#` progression |
| `GL_UP`            | U+2191                                   | `^`             |
| `GL_DOWN`          | U+2193                                   | `v`             |

Braille buckets (used by sparkline + `braille` gauge): `GL_BRL_0='\u2800'` (empty), `GL_BRL_1='\u2801'`, `GL_BRL_2='\u2803'`, `GL_BRL_3='\u2807'`, `GL_BRL_4='\u280F'`, `GL_BRL_5='\u281F'`, `GL_BRL_6='\u283F'`, `GL_BRL_7='\u287F'`, `GL_BRL_8='\u28FF'`.

### C5. Cache files

- Burn-rate sparkline: `"$SL_CACHE_DIR/burn-history"` (single line, 8 comma-separated integers, oldest first)
- Cache directory: `$TMPDIR/claude-statusline-cache/$(whoami)` — already established in `lib/cache.sh`, reuse
- All integer values: sanitize via `printf '%d'` before write
- TTL: 5s, enforced by stat mtime check
- Permissions: dir 0700, files 0600

### C6. Run-time state variables (set by `main.sh`, read by segments)

Added in v2 (prefix `sl_` per CLAUDE.md):

- `sl_rate_5h_pct` (integer 0-100 or empty)
- `sl_rate_5h_reset_ts` (unix epoch seconds or empty)
- `sl_rate_7d_pct` (integer 0-100 or empty)
- `sl_rate_7d_reset_ts` (unix epoch seconds or empty)
- `sl_output_style` (string or empty; compare != "default")
- `sl_session_name` (string or empty)
- `sl_added_dirs_count` (integer >= 0)
- `sl_api_duration_ms` (integer >= 0 or empty)
- `sl_project_dir` (string or empty; fallback to `sl_cwd`)

Added session-scoped internal (prefix `_sl_`):

- `_sl_layout` (`classic` or `zen` — post-validation of env var)

### C7. Priority rules (canonical order)

**`segment_alerts_slot` (Row 1 / session group, min_tier=full)** — emits FIRST match:

1. `cache-poor`: `sl_cache_read_tokens > 0` AND computed hit ratio `< 70`
2. `added-dirs`: `sl_added_dirs_count > 0`
3. `7d-warning`: `$_sl_layout = "zen"` AND `sl_rate_7d_pct >= 70`

**`segment_info_slot` (Row 3 / ambient group, workspace fallback, min_tier=full)** — emits FIRST match:

1. `output-style`: `sl_output_style` present AND `!= "default"`
2. `subdir`: `sl_cwd != sl_project_dir` AND cwd is a prefix-proper descendant of project_dir
3. `session-name`: `sl_session_name` present
4. `clock`: always true (fallback)

### C8. Tier detection (new logic in `main.sh`)

```sh
_sl_layout="${CLAUDE_STATUSLINE_LAYOUT:-classic}"
case "$_sl_layout" in classic|zen) ;; *) _sl_layout=classic ;; esac

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

### C9. Segment registration order (final `SL_SEGMENTS` in `main.sh`)

```
segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_alerts_slot \
  segment_micro_location \
  segment_project segment_git segment_info_slot \
  segment_rate_limit_7d_stable \
  segment_lines segment_worktree segment_duration
```

`segment_cache_stats` is REMOVED. Its file `lib/segments/cache-stats.sh` is deleted.

### C10. Testing / verification contract

- Every task MUST run `sh -n <file>` on any shell files it creates or modifies.
- Every task that changes rendering MUST run `sh test/run.sh --check` and report PASS count.
- Every task MUST leave `git status` clean (committed) before returning.
- Commit messages follow `feat(scope): ...` / `fix(scope): ...` / `docs(scope): ...` / `test(scope): ...` / `refactor(scope): ...`.
- Scope examples: `rate-limit`, `alerts-slot`, `info-slot`, `git`, `duration`, `ctx-gauge`, `zen-layout`, `render`, `main`, `cache`, `config`, `tests`, `docs`.
- NEVER commit unless the syntax check + test suite pass. A commit with a broken test suite is a plan failure.

---

## File Structure Map

### Files to create

| Path                                         | Responsibility                                                                                  |
|----------------------------------------------|-------------------------------------------------------------------------------------------------|
| `lib/segments/rate-limit.sh`                 | 5h rate-limit pill with 4 presets (ember/bar/pill/minimal). Row 1 / session group.              |
| `lib/segments/rate-limit-7d-stable.sh`       | 7d always-visible recessed pill. zen-only (self-gates on `$_sl_layout`). Ambient group.         |
| `lib/segments/alerts-slot.sh`                | Priority-rotating conditional alerts pill. Row 1 / session group.                               |
| `lib/segments/info-slot.sh`                  | Priority-rotating informational pill. Ambient group with workspace fallback.                    |
| `docs/CONFIG.md`                             | Full reference for every env var + config file pattern with examples.                           |
| `test/fixtures/rate-healthy.json`            | Rate 5h 22%, 7d 18%, healthy context.                                                           |
| `test/fixtures/rate-warming.json`            | Rate 5h 65%, 7d 52%, output-style set, subdir active, session-name, added_dirs > 0.             |
| `test/fixtures/rate-critical.json`           | 5h 92% projected burn, 7d 74%, context 96%, cache 43%, rebase in progress.                      |
| `test/fixtures/zen-full.json`                | Full payload for zen-mode render with every conditional firing.                                 |

### Files to modify

| Path                                         | Change summary                                                                                  |
|----------------------------------------------|-------------------------------------------------------------------------------------------------|
| `main.sh`                                    | Config file sourcing; new JSON fields; new tier logic; new `SL_SEGMENTS`; remove cache-stats.   |
| `lib/render.sh`                              | New glyphs (C4); new gauge helper; cap-shape wiring; minimalist mode handling; ambient weight guard. |
| `lib/cache.sh`                               | Add `sparkline_push / sparkline_read` helpers for the 8-sample ring buffer.                     |
| `lib/segments/context.sh`                    | V1 pluggable gauge via `CLAUDE_STATUSLINE_CTX_GAUGE`.                                           |
| `lib/segments/burn-rate.sh`                  | Append braille sparkline tail via new cache helper.                                             |
| `lib/segments/git.sh`                        | Staged/unstaged/untracked split; conflicts override; fork badge.                                |
| `lib/segments/duration.sh`                   | API-time suffix + escalation color.                                                             |
| `test/run.sh`                                | Add new scenario + layout permutations to `--check`; performance benchmark.                     |
| `README.md`                                  | Zen mode, revised feature list, config file example.                                            |
| `CONTRIBUTING.md`                            | Document `_seg_group_fallback`, ambient group, new segment template.                            |
| `CLAUDE.md`                                  | Architecture updates: 4 tiers, 3 groups, new segments, new JSON schema, new env vars.           |

### Files to delete

- `lib/segments/cache-stats.sh`

---

## Parallelization Graph

Letters = phases. Tasks within the same letter can be dispatched in parallel. Tasks in later letters assume the previous letter's tasks are complete and committed.

```
A. Preflight                 [1]
B. Foundation (parallel)     [2] [3] [4] [5] [6]
C. New segments (sequential)  [7] -> [8] -> [9] -> [10] -> [11] -> [12]
D. Upgrades (parallel)       [13] [14] [15] [16] [17] [18]
E. Visual system (sequential)[19] -> [20] -> [21] -> [22]
F. Hygiene (parallel)        [23] [24] [25] [26] [27] [28]
```

---

## Task 1: Preflight — confirm clean baseline and branch

**Files:**
- Verify: `test/run.sh` passes on current branch
- Confirm: current branch is `feat/v2-statusline-enhancements`

- [ ] **Step 1: Confirm the working branch**

Run: `git rev-parse --abbrev-ref HEAD`
Expected: `feat/v2-statusline-enhancements`

If not on that branch: `git checkout feat/v2-statusline-enhancements` (branch already exists; was created when the spec was committed).

- [ ] **Step 2: Confirm working tree is clean**

Run: `git status --porcelain`
Expected: empty output.

If output is non-empty, stop and surface to the human. Do not stash.

- [ ] **Step 3: Run baseline tests**

Run: `sh test/run.sh --check`
Expected: `Results: 48 passed, 0 failed, 48 total`

If count differs, stop and surface. The plan assumes 48 as the baseline.

- [ ] **Step 4: Record baseline**

No file change. Note the count. This task has no commit.

---

## Task 2: New JSON field extraction in `main.sh`

**Files:**
- Modify: `main.sh:35-61`
- Test: `test/run.sh` (existing suite)

Dependency: none. Parallel-safe with 3, 4, 5, 6.

- [ ] **Step 1: Write the failing test**

Create fixture `test/fixtures/rate-warming.json` (full content in Task 6 — for now, write a minimal version to drive this task):

```json
{
  "cwd": "/Users/me/projects/app",
  "model": {"id": "claude-opus-4-7", "display_name": "Claude Opus"},
  "context_window": {"used_percentage": 65, "context_window_size": 200000, "current_usage": {"input_tokens": 1000, "output_tokens": 500, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}, "total_input_tokens": 10000, "total_output_tokens": 2000},
  "cost": {"total_duration_ms": 1080000, "total_lines_added": 0, "total_lines_removed": 0, "total_api_duration_ms": 480000},
  "rate_limits": {"five_hour": {"used_percentage": 65, "resets_at": 9999999999}, "seven_day": {"used_percentage": 52, "resets_at": 9999999999}},
  "output_style": {"name": "Explanatory"},
  "session_name": "refactor-auth",
  "workspace": {"current_dir": "/Users/me/projects/app", "project_dir": "/Users/me/projects/app", "added_dirs": ["/extra/dir1", "/extra/dir2"]}
}
```

- [ ] **Step 2: Run the test expecting the new variables to still be empty**

Run: `cat test/fixtures/rate-warming.json | sh main.sh 2>&1 | head -5`
Expected: current status line renders (no new vars used yet). No errors.

- [ ] **Step 3: Extend the jq call**

Replace `main.sh:35-61` with:

```sh
sl_cwd="" ; sl_model_id="" ; sl_model_name=""
sl_used_pct="" ; sl_ctx_size=""
sl_input_tokens="" ; sl_output_tokens=""
sl_cache_create_tokens="" ; sl_cache_read_tokens=""
sl_total_input_tokens="" ; sl_total_output_tokens=""
sl_duration_ms="" ; sl_lines_added="" ; sl_lines_removed=""
sl_worktree_name="" ; sl_agent_name="" ; sl_exceeds_200k=""
sl_rate_5h_pct="" ; sl_rate_5h_reset_ts=""
sl_rate_7d_pct="" ; sl_rate_7d_reset_ts=""
sl_output_style="" ; sl_session_name=""
sl_added_dirs_count="" ; sl_api_duration_ms=""
sl_project_dir=""

_jq_out=$(echo "$sl_input" | jq -r '
  "sl_cwd=" + (.cwd // .workspace.current_dir // "" | @sh),
  "sl_model_id=" + (.model.id // "" | @sh),
  "sl_model_name=" + (.model.display_name // "" | @sh),
  "sl_used_pct=" + (.context_window.used_percentage // "" | tostring | @sh),
  "sl_ctx_size=" + (.context_window.context_window_size // "" | tostring | @sh),
  "sl_input_tokens=" + (.context_window.current_usage.input_tokens // "" | tostring | @sh),
  "sl_output_tokens=" + (.context_window.current_usage.output_tokens // "" | tostring | @sh),
  "sl_cache_create_tokens=" + (.context_window.current_usage.cache_creation_input_tokens // "" | tostring | @sh),
  "sl_cache_read_tokens=" + (.context_window.current_usage.cache_read_input_tokens // "" | tostring | @sh),
  "sl_total_input_tokens=" + (.context_window.total_input_tokens // "" | tostring | @sh),
  "sl_total_output_tokens=" + (.context_window.total_output_tokens // "" | tostring | @sh),
  "sl_duration_ms=" + (.cost.total_duration_ms // "" | tostring | @sh),
  "sl_lines_added=" + (.cost.total_lines_added // "" | tostring | @sh),
  "sl_lines_removed=" + (.cost.total_lines_removed // "" | tostring | @sh),
  "sl_worktree_name=" + (.worktree.name // "" | @sh),
  "sl_agent_name=" + (.agent.name // "" | @sh),
  "sl_exceeds_200k=" + (.exceeds_200k_tokens // false | tostring | @sh),
  "sl_rate_5h_pct=" + (.rate_limits.five_hour.used_percentage // "" | tostring | @sh),
  "sl_rate_5h_reset_ts=" + (.rate_limits.five_hour.resets_at // "" | tostring | @sh),
  "sl_rate_7d_pct=" + (.rate_limits.seven_day.used_percentage // "" | tostring | @sh),
  "sl_rate_7d_reset_ts=" + (.rate_limits.seven_day.resets_at // "" | tostring | @sh),
  "sl_output_style=" + (.output_style.name // "" | @sh),
  "sl_session_name=" + (.session_name // "" | @sh),
  "sl_added_dirs_count=" + (.workspace.added_dirs // [] | length | tostring | @sh),
  "sl_api_duration_ms=" + (.cost.total_api_duration_ms // "" | tostring | @sh),
  "sl_project_dir=" + (.workspace.project_dir // .cwd // "" | @sh)
' 2>/dev/null) && eval "$_jq_out"
```

- [ ] **Step 4: Syntax check**

Run: `sh -n main.sh`
Expected: no output (syntax OK).

- [ ] **Step 5: Run all existing tests**

Run: `sh test/run.sh --check`
Expected: `48 passed, 0 failed`.

- [ ] **Step 6: Verify new fields parse**

Run:
```sh
cat test/fixtures/rate-warming.json | sh -c '
. lib/theme.sh 2>/dev/null
sl_input=$(cat)
# copy the jq block from main.sh up to and including eval, then echo vars:
' 2>/dev/null || true
```

Simpler verification — create `/tmp/inspect.sh`:

```sh
#!/bin/sh
sl_input=$(cat)
_jq_out=$(echo "$sl_input" | jq -r '
  "sl_rate_5h_pct=" + (.rate_limits.five_hour.used_percentage // "" | tostring | @sh),
  "sl_output_style=" + (.output_style.name // "" | @sh),
  "sl_session_name=" + (.session_name // "" | @sh),
  "sl_added_dirs_count=" + (.workspace.added_dirs // [] | length | tostring | @sh)
') && eval "$_jq_out"
printf '5h=%s style=%s name=%s dirs=%s\n' "$sl_rate_5h_pct" "$sl_output_style" "$sl_session_name" "$sl_added_dirs_count"
```

Run: `cat test/fixtures/rate-warming.json | sh /tmp/inspect.sh`
Expected: `5h=65 style=Explanatory name=refactor-auth dirs=2`

Delete `/tmp/inspect.sh` afterwards.

- [ ] **Step 7: Commit**

```sh
git add main.sh test/fixtures/rate-warming.json
git commit -m "feat(main): extract rate_limits, output_style, session_name, added_dirs from JSON"
```

---

## Task 3: Config file loading + layout env var handling in `main.sh`

**Files:**
- Modify: `main.sh:1-32`

Dependency: none. Parallel-safe with 2, 4, 5, 6.

- [ ] **Step 1: Add config-file sourcing near the top of `main.sh`**

Insert after line 10 (`SL_LIB="$SL_DIR/lib"`) and before the `sl_input=$(cat)` line:

```sh
# --- Config file sourcing (before reading other env vars) ---
_sl_cfg="${CLAUDE_STATUSLINE_CONFIG_FILE:-$HOME/.config/claude-statusline/config.sh}"
[ -r "$_sl_cfg" ] && . "$_sl_cfg"
```

- [ ] **Step 2: Add layout validation + zen tier branch**

Replace the tier detection block (lines 23-32) with:

```sh
# --- Tier detection ---
_sl_cols="${COLUMNS:-120}"
_sl_layout="${CLAUDE_STATUSLINE_LAYOUT:-classic}"
case "$_sl_layout" in classic|zen) ;; *) _sl_layout=classic ;; esac

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

- [ ] **Step 3: Syntax check**

Run: `sh -n main.sh`
Expected: no output.

- [ ] **Step 4: Test config-file loading**

```sh
mkdir -p /tmp/csl-cfg
cat > /tmp/csl-cfg/config.sh <<'EOF'
CLAUDE_STATUSLINE_THEME=dracula
EOF
CLAUDE_STATUSLINE_CONFIG_FILE=/tmp/csl-cfg/config.sh cat test/fixtures/full.json | sh main.sh > /tmp/out.txt
grep -q . /tmp/out.txt && echo "renders OK" || echo "empty output"
rm -rf /tmp/csl-cfg /tmp/out.txt
```
Expected: `renders OK`.

- [ ] **Step 5: Test zen tier branch**

```sh
CLAUDE_STATUSLINE_LAYOUT=zen COLUMNS=150 cat test/fixtures/full.json | sh main.sh | wc -l
```
Expected: `2` (existing layout still used; zen segments not implemented yet, but tier var is set — only 2 rows render because no `ambient` segments exist yet). Tolerated outcome this early in the plan.

- [ ] **Step 6: Run all existing tests**

Run: `sh test/run.sh --check`
Expected: `48 passed, 0 failed`.

- [ ] **Step 7: Commit**

```sh
git add main.sh
git commit -m "feat(main): add config file loading and CLAUDE_STATUSLINE_LAYOUT with zen tier branch"
```

---

## Task 4: Sparkline ring-buffer cache helpers in `lib/cache.sh`

**Files:**
- Modify: `lib/cache.sh` (append new helpers)

Dependency: none. Parallel-safe with 2, 3, 5, 6.

- [ ] **Step 1: Read `lib/cache.sh` to confirm the cache-dir pattern**

Run: `grep -n CACHE_DIR lib/cache.sh`
Expected: finds `SL_CACHE_DIR` or equivalent. If not, the cache module uses another pattern — adapt accordingly by following the existing git-cache layout exactly.

- [ ] **Step 2: Append sparkline helpers**

Append to `lib/cache.sh`:

```sh
# --- Sparkline ring buffer (8 samples) ---
# File: $SL_CACHE_DIR/burn-history
# Format: single line, 8 comma-separated non-negative integers, oldest first
# Reader/writer use printf '%d' to sanitize.

sparkline_push() {
  # args: value (integer, tokens/minute)
  # Appends to ring buffer, keeps newest 8.
  _sp_val=$(printf '%d' "${1:-0}" 2>/dev/null || echo 0)
  _sp_file="$SL_CACHE_DIR/burn-history"
  mkdir -p "$SL_CACHE_DIR" 2>/dev/null
  chmod 0700 "$SL_CACHE_DIR" 2>/dev/null
  _sp_cur=""
  [ -r "$_sp_file" ] && _sp_cur=$(cat "$_sp_file" 2>/dev/null)
  # Append new value, split, keep last 8
  if [ -z "$_sp_cur" ]; then
    _sp_new="$_sp_val"
  else
    _sp_new="${_sp_cur},${_sp_val}"
  fi
  # Count commas; if > 7, drop from the front
  _sp_count=$(printf '%s\n' "$_sp_new" | tr ',' '\n' | wc -l | tr -d ' ')
  while [ "$_sp_count" -gt 8 ]; do
    _sp_new="${_sp_new#*,}"
    _sp_count=$(( _sp_count - 1 ))
  done
  printf '%s\n' "$_sp_new" > "$_sp_file"
  chmod 0600 "$_sp_file" 2>/dev/null
}

sparkline_read() {
  # Prints the current ring as comma-separated, or empty string if missing.
  _sp_file="$SL_CACHE_DIR/burn-history"
  [ -r "$_sp_file" ] && cat "$_sp_file" 2>/dev/null
}
```

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/cache.sh`
Expected: no output.

- [ ] **Step 4: Smoke-test the helpers**

```sh
mkdir -p /tmp/csl-spark-test
SL_CACHE_DIR=/tmp/csl-spark-test sh -c '. lib/cache.sh
sparkline_push 100
sparkline_push 200
sparkline_push 150
printf "buffer: %s\n" "$(sparkline_read)"'
rm -rf /tmp/csl-spark-test
```
Expected: `buffer: 100,200,150`

- [ ] **Step 5: Smoke-test the ring-buffer cap**

```sh
mkdir -p /tmp/csl-spark-test
SL_CACHE_DIR=/tmp/csl-spark-test sh -c '. lib/cache.sh
for i in 1 2 3 4 5 6 7 8 9 10; do sparkline_push "$i"; done
printf "buffer: %s\n" "$(sparkline_read)"'
rm -rf /tmp/csl-spark-test
```
Expected: `buffer: 3,4,5,6,7,8,9,10` (only last 8 kept).

- [ ] **Step 6: Run all existing tests**

Run: `sh test/run.sh --check`
Expected: `48 passed, 0 failed`.

- [ ] **Step 7: Commit**

```sh
git add lib/cache.sh
git commit -m "feat(cache): add sparkline_push/sparkline_read ring-buffer helpers"
```

---

## Task 5: New glyph variables + capability extension in `lib/render.sh`

**Files:**
- Modify: `lib/render.sh:7-70` (`detect_capabilities` function)

Dependency: none. Parallel-safe with 2, 3, 4, 6.

- [ ] **Step 1: Add new glyph definitions to the Nerd-Font branch**

After the existing `GL_THIN_SEP='\xe2\x94\x82'` line (around line 38) but still inside the `if [ "$SL_CAP_NERD" -eq 1 ]` branch, add:

```sh
    GL_BATT_FULL='\xef\x89\x80'        # U+F240 nf-fa-battery_full
    GL_BATT_MID='\xef\x89\x82'         # U+F242 nf-fa-battery_half
    GL_BATT_LOW='\xef\x89\x84'         # U+F244 nf-fa-battery_quarter
    GL_FORK='\xee\x9c\xa5'             # U+E725 reuse git branch glyph as minimal fork marker
    GL_CAP_LEFT='\xee\x82\xb6'         # U+E0B6 powerline round left
    GL_CAP_RIGHT='\xee\x82\xb4'        # U+E0B4 powerline round right
    GL_UP='\xe2\x86\x91'               # U+2191
    GL_DOWN='\xe2\x86\x93'             # U+2193
```

And inside the ASCII fallback branch (after `GL_THIN_SEP='|'`):

```sh
    GL_BATT_FULL='FULL'
    GL_BATT_MID='MID'
    GL_BATT_LOW='LOW'
    GL_FORK='fork'
    GL_CAP_LEFT='('
    GL_CAP_RIGHT=')'
    GL_UP='^'
    GL_DOWN='v'
```

- [ ] **Step 2: Add unicode-gated glyph tables for gauges**

After the existing dot/arrow block (inside `if [ "$SL_CAP_UNICODE" -eq 1 ]`), add:

```sh
    GL_BLK_FILLED='\xe2\x96\x93'       # U+2593
    GL_BLK_EMPTY='\xe2\x96\x91'        # U+2591
    GL_PIP_FILLED='\xc2\xb7'           # U+00B7 middle dot
    GL_PIP_EMPTY=' '
    GL_BRL_0='\xe2\xa0\x80'            # U+2800
    GL_BRL_1='\xe2\xa0\x81'            # U+2801
    GL_BRL_2='\xe2\xa0\x83'            # U+2803
    GL_BRL_3='\xe2\xa0\x87'            # U+2807
    GL_BRL_4='\xe2\xa0\x8f'            # U+280F
    GL_BRL_5='\xe2\xa0\x9f'            # U+281F
    GL_BRL_6='\xe2\xa0\xbf'            # U+283F
    GL_BRL_7='\xe2\xa1\xbf'            # U+287F
    GL_BRL_8='\xe2\xa3\xbf'            # U+28FF
```

In the ASCII fallback branch:

```sh
    GL_BLK_FILLED='#'
    GL_BLK_EMPTY='.'
    GL_PIP_FILLED='*'
    GL_PIP_EMPTY=' '
    GL_BRL_0='_'
    GL_BRL_1='_'
    GL_BRL_2='.'
    GL_BRL_3='.'
    GL_BRL_4='-'
    GL_BRL_5='-'
    GL_BRL_6='='
    GL_BRL_7='+'
    GL_BRL_8='#'
```

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/render.sh`
Expected: no output.

- [ ] **Step 4: Verify glyphs are bound**

```sh
SL_DIR=. SL_LIB=./lib sh -c '. ./lib/theme.sh
. ./lib/render.sh
detect_capabilities
for v in GL_BATT_FULL GL_BATT_MID GL_BATT_LOW GL_FORK GL_CAP_LEFT GL_CAP_RIGHT GL_UP GL_DOWN \
         GL_BLK_FILLED GL_BLK_EMPTY GL_PIP_FILLED GL_BRL_0 GL_BRL_4 GL_BRL_8; do
  eval "val=\$$v"
  [ -z "$val" ] && echo "MISSING: $v"
done
echo "ALL OK"'
```
Expected: `ALL OK` (no MISSING lines).

- [ ] **Step 5: Run all existing tests**

Run: `sh test/run.sh --check`
Expected: `48 passed, 0 failed` (this change only adds unused glyphs; should be behavior-neutral).

- [ ] **Step 6: Commit**

```sh
git add lib/render.sh
git commit -m "feat(render): add battery, fork, capsule-cap, block, pip, and braille glyph tables"
```

---

## Task 6: Add test fixtures for rate-limit + zen scenarios

**Files:**
- Create: `test/fixtures/rate-healthy.json`
- Modify (finalize): `test/fixtures/rate-warming.json` (created in Task 2)
- Create: `test/fixtures/rate-critical.json`
- Create: `test/fixtures/zen-full.json`

Dependency: none (writes fixture files only). Parallel-safe with 2, 3, 4, 5.

- [ ] **Step 1: Create `test/fixtures/rate-healthy.json`**

```json
{
  "cwd": "/Users/me/projects/app",
  "model": {"id": "claude-opus-4-7", "display_name": "Claude Opus"},
  "context_window": {"used_percentage": 22, "context_window_size": 150000, "current_usage": {"input_tokens": 5000, "output_tokens": 2000, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}, "total_input_tokens": 8000, "total_output_tokens": 3000},
  "cost": {"total_duration_ms": 240000, "total_lines_added": 12, "total_lines_removed": 3, "total_api_duration_ms": 180000},
  "rate_limits": {"five_hour": {"used_percentage": 22, "resets_at": 9999999999}, "seven_day": {"used_percentage": 18, "resets_at": 9999999999}},
  "output_style": {"name": "default"},
  "workspace": {"current_dir": "/Users/me/projects/app", "project_dir": "/Users/me/projects/app", "added_dirs": []}
}
```

- [ ] **Step 2: Finalize `test/fixtures/rate-warming.json`**

Overwrite the minimal version from Task 2 with:

```json
{
  "cwd": "/Users/me/projects/app/src/auth",
  "model": {"id": "claude-opus-4-7", "display_name": "Claude Opus"},
  "context_window": {"used_percentage": 55, "context_window_size": 150000, "current_usage": {"input_tokens": 30000, "output_tokens": 10000, "cache_creation_input_tokens": 15000, "cache_read_input_tokens": 80000}, "total_input_tokens": 120000, "total_output_tokens": 40000},
  "cost": {"total_duration_ms": 2040000, "total_lines_added": 142, "total_lines_removed": 38, "total_api_duration_ms": 480000},
  "rate_limits": {"five_hour": {"used_percentage": 65, "resets_at": 9999999999}, "seven_day": {"used_percentage": 52, "resets_at": 9999999999}},
  "output_style": {"name": "Explanatory"},
  "session_name": "refactor-auth",
  "workspace": {"current_dir": "/Users/me/projects/app/src/auth", "project_dir": "/Users/me/projects/app", "added_dirs": ["/extra/dir1", "/extra/dir2"]}
}
```

- [ ] **Step 3: Create `test/fixtures/rate-critical.json`**

```json
{
  "cwd": "/Users/me/projects/app",
  "model": {"id": "claude-opus-4-7", "display_name": "Claude Opus"},
  "context_window": {"used_percentage": 96, "context_window_size": 200000, "current_usage": {"input_tokens": 80000, "output_tokens": 30000, "cache_creation_input_tokens": 5000, "cache_read_input_tokens": 8000}, "total_input_tokens": 190000, "total_output_tokens": 75000, "exceeds_200k_tokens": false},
  "cost": {"total_duration_ms": 4320000, "total_lines_added": 142, "total_lines_removed": 38, "total_api_duration_ms": 840000},
  "rate_limits": {"five_hour": {"used_percentage": 92, "resets_at": 9999999999}, "seven_day": {"used_percentage": 74, "resets_at": 9999999999}},
  "output_style": {"name": "default"},
  "workspace": {"current_dir": "/Users/me/projects/app", "project_dir": "/Users/me/projects/app", "added_dirs": []}
}
```

- [ ] **Step 4: Create `test/fixtures/zen-full.json`**

```json
{
  "cwd": "/Users/me/projects/app/src/auth",
  "model": {"id": "claude-opus-4-7", "display_name": "Claude Opus"},
  "context_window": {"used_percentage": 55, "context_window_size": 150000, "current_usage": {"input_tokens": 30000, "output_tokens": 10000, "cache_creation_input_tokens": 15000, "cache_read_input_tokens": 80000}, "total_input_tokens": 120000, "total_output_tokens": 40000},
  "cost": {"total_duration_ms": 2040000, "total_lines_added": 142, "total_lines_removed": 38, "total_api_duration_ms": 480000},
  "rate_limits": {"five_hour": {"used_percentage": 35, "resets_at": 9999999999}, "seven_day": {"used_percentage": 52, "resets_at": 9999999999}},
  "output_style": {"name": "Explanatory"},
  "session_name": "refactor-auth",
  "workspace": {"current_dir": "/Users/me/projects/app/src/auth", "project_dir": "/Users/me/projects/app", "added_dirs": ["/extra/dir1"]}
}
```

- [ ] **Step 5: JSON validity check**

Run: `for f in test/fixtures/rate-*.json test/fixtures/zen-full.json; do jq empty "$f" || echo "BROKEN: $f"; done`
Expected: no `BROKEN:` lines.

- [ ] **Step 6: Commit**

```sh
git add test/fixtures/rate-healthy.json test/fixtures/rate-warming.json test/fixtures/rate-critical.json test/fixtures/zen-full.json
git commit -m "test(fixtures): add rate-healthy/warming/critical and zen-full scenarios"
```

---

## Task 7: Implement `segment_rate_limit` (Ember default)

**Files:**
- Create: `lib/segments/rate-limit.sh`

Dependency: Tasks 2, 5 complete.

- [ ] **Step 1: Write the segment file**

Create `lib/segments/rate-limit.sh`:

```sh
#!/bin/sh
# segments/rate-limit.sh -- 5h rate-limit pill with configurable presets
# Reads: sl_rate_5h_pct, sl_rate_5h_reset_ts, sl_rate_7d_pct, _sl_layout, _sl_tier
# Env:   CLAUDE_STATUSLINE_RATE_STYLE (ember|bar|pill|minimal)

segment_rate_limit() {
  _rl_5h=$(( sl_rate_5h_pct + 0 )) 2>/dev/null || _rl_5h=-1
  [ "$_rl_5h" -lt 0 ] && return 1

  _seg_group="session"
  _seg_min_tier="micro"
  _seg_attrs=""
  _seg_icon=""

  # Time-remaining computation
  _rl_now=$(date +%s)
  _rl_reset=$(( sl_rate_5h_reset_ts + 0 )) 2>/dev/null || _rl_reset=0
  _rl_secs=$(( _rl_reset - _rl_now ))
  [ "$_rl_secs" -lt 0 ] && _rl_secs=0
  _rl_min=$(( _rl_secs / 60 ))
  _rl_h=$(( _rl_min / 60 ))
  _rl_m=$(( _rl_min % 60 ))

  # Format "XhYm" or "Ym" (no leading hour when zero)
  if [ "$_rl_h" -gt 0 ]; then
    _rl_time="${_rl_h}h${_rl_m}m"
  else
    _rl_time="${_rl_m}m"
  fi

  # State thresholds
  if [ "$_rl_5h" -ge 85 ]; then
    _rl_state="crit"
  elif [ "$_rl_5h" -ge 50 ]; then
    _rl_state="warm"
  else
    _rl_state="ok"
  fi

  # Weight + color
  case "$_rl_state" in
    crit) _seg_weight="primary"; _seg_bg=$C_CTX_CRIT_BG; _seg_fg=$C_CTX_CRIT_FG ; _seg_attrs="bold" ;;
    warm) _seg_weight="tertiary"; _seg_fg=$C_DUR_MED ;;
    ok)   _seg_weight="tertiary"; _seg_fg=$C_DUR_LOW ;;
  esac

  # Preset selection
  _rl_style="${CLAUDE_STATUSLINE_RATE_STYLE:-ember}"
  case "$_rl_style" in ember|bar|pill|minimal) ;; *) _rl_style=ember ;; esac

  # Ember default rendering
  case "$_rl_style" in
    ember)
      case "$_rl_state" in
        ok)   _rl_glyph="$GL_BATT_FULL" ;;
        warm) _rl_glyph="$GL_BATT_MID" ;;
        crit) _rl_glyph="$GL_BATT_LOW" ;;
      esac
      _rl_left=$(( 100 - _rl_5h ))
      if [ "$_rl_state" = "crit" ]; then
        # ETA for "burns in Xm" when pace > 1.0
        # Simple model: if used > elapsed percent, show burn ETA.
        _rl_burn_label=""
        if [ "$_rl_reset" -gt 0 ] && [ "$_rl_5h" -gt 0 ]; then
          # elapsed_sec = 18000 - remaining_sec; elapsed_pct = elapsed_sec*100/18000
          _rl_elapsed=$(( 18000 - _rl_secs ))
          [ "$_rl_elapsed" -lt 1 ] && _rl_elapsed=1
          _rl_elapsed_pct=$(( _rl_elapsed * 100 / 18000 ))
          if [ "$_rl_5h" -gt "$_rl_elapsed_pct" ] && [ "$_rl_elapsed_pct" -gt 0 ]; then
            # projected seconds to 100 at current rate: 18000 * 100 / _rl_5h * (elapsed/18000)
            _rl_burn_sec=$(( _rl_elapsed * 100 / _rl_5h - _rl_elapsed ))
            [ "$_rl_burn_sec" -lt 0 ] && _rl_burn_sec=0
            _rl_burn_min=$(( _rl_burn_sec / 60 ))
            _rl_burn_label=" burns in ${_rl_burn_min}m ${GL_UP}"
          fi
        fi
        _seg_content="${_rl_glyph}${_rl_burn_label} ${_rl_5h}% left . ${_rl_time} reset"
      elif [ "$_rl_state" = "warm" ]; then
        _rl_7d_inline=""
        _rl_7d=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _rl_7d=-1
        if [ "$_sl_layout" != "zen" ] && [ "$_rl_7d" -ge 50 ]; then
          _rl_7d_inline=" . 7d ${_rl_7d}%"
        fi
        _seg_content="${_rl_glyph} ${_rl_time} left . ${_rl_5h}%${_rl_7d_inline}"
      else
        _seg_content="${_rl_glyph} ${_rl_time} left . ${_rl_left}%"
      fi
      ;;
    minimal)
      _seg_content="${_rl_time} . ${_rl_5h}%"
      ;;
    pill)
      _rl_7d=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _rl_7d=-1
      if [ "$_rl_7d" -ge 0 ]; then
        _seg_content="5h ${_rl_5h}% . ${_rl_time} | 7d ${_rl_7d}%"
      else
        _seg_content="5h ${_rl_5h}% . ${_rl_time}"
      fi
      ;;
    bar)
      # position = elapsed%, fill = _rl_5h
      _rl_bar_filled=$(( _rl_5h / 10 ))
      [ "$_rl_bar_filled" -gt 10 ] && _rl_bar_filled=10
      _rl_bar=""
      _rl_bi=0; while [ "$_rl_bi" -lt "$_rl_bar_filled" ]; do _rl_bar="${_rl_bar}${GL_BLK_FILLED}"; _rl_bi=$((_rl_bi+1)); done
      _rl_bi=0; while [ "$_rl_bi" -lt $(( 10 - _rl_bar_filled )) ]; do _rl_bar="${_rl_bar}${GL_BLK_EMPTY}"; _rl_bi=$((_rl_bi+1)); done
      _seg_content="5h ${_rl_bar} ${_rl_5h}% . ${_rl_time}"
      ;;
  esac

  # Compact tier: drop 7d inline
  if [ "$_sl_tier" = "compact" ]; then
    _seg_content="${_rl_glyph:-} ${_rl_time} . ${_rl_5h}%"
  fi
  # Micro tier
  if [ "$_sl_tier" = "micro" ]; then
    _seg_content="${_rl_glyph:-} ${_rl_time}"
  fi

  return 0
}
```

- [ ] **Step 2: Register the segment in `SL_SEGMENTS`**

Edit `main.sh`. Locate the `SL_SEGMENTS=` assignment (around line 82) and insert `segment_rate_limit` between `segment_context` and `segment_burn_rate`:

```sh
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_cache_stats \
  segment_micro_location \
  segment_project segment_git segment_lines \
  segment_worktree segment_duration"
```

(`segment_cache_stats` is still there; removal happens in Task 12.)

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/segments/rate-limit.sh main.sh`
Expected: no output.

- [ ] **Step 4: Smoke-render with warming fixture**

Run: `COLUMNS=150 cat test/fixtures/rate-warming.json | sh main.sh`
Expected: the status line now includes `1h48m left . 65% . 7d 52%` or similar in the session row.

- [ ] **Step 5: Smoke-render with critical fixture**

Run: `COLUMNS=150 cat test/fixtures/rate-critical.json | sh main.sh`
Expected: includes `burns in Xm` for some X; escalates to red critical styling.

- [ ] **Step 6: Run existing tests**

Run: `sh test/run.sh --check`
Expected: 48 passing. If some fail due to added content in rendered output, adjust the snapshot expectations — but the snapshot tests check theme/layout validity, not exact strings, per `test/run.sh`. Re-read the check script if failures surface.

- [ ] **Step 7: Commit**

```sh
git add lib/segments/rate-limit.sh main.sh
git commit -m "feat(rate-limit): add segment with ember default + bar/pill/minimal presets"
```

---

## Task 8: Implement `segment_rate_limit_7d_stable`

**Files:**
- Create: `lib/segments/rate-limit-7d-stable.sh`

Dependency: Task 7 complete.

- [ ] **Step 1: Write the segment file**

Create `lib/segments/rate-limit-7d-stable.sh`:

```sh
#!/bin/sh
# segments/rate-limit-7d-stable.sh -- 7d rate-limit stable pill (zen Row 3 only)
# Self-gates on $_sl_layout and 7d threshold. Returns non-zero outside zen
# or when 7d >= 70% (that case is handled by segment_alerts_slot).

segment_rate_limit_7d_stable() {
  [ "$_sl_layout" != "zen" ] && return 1

  _r7_pct=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _r7_pct=-1
  [ "$_r7_pct" -lt 0 ] && return 1
  [ "$_r7_pct" -ge 70 ] && return 1

  # Days remaining
  _r7_now=$(date +%s)
  _r7_reset=$(( sl_rate_7d_reset_ts + 0 )) 2>/dev/null || _r7_reset=0
  _r7_secs=$(( _r7_reset - _r7_now ))
  [ "$_r7_secs" -lt 0 ] && _r7_secs=0
  _r7_days=$(( _r7_secs / 86400 ))

  _seg_weight="recessed"
  _seg_min_tier="zen"
  _seg_group="ambient"
  _seg_group_fallback=""   # does not render in classic
  _seg_icon=""
  _seg_attrs=""
  _seg_content="7d ${_r7_pct}% . ${_r7_days}d"

  return 0
}
```

- [ ] **Step 2: Register segment in `SL_SEGMENTS`**

Edit `main.sh`, add to the segments list so the final form is (cache_stats still present):

```sh
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_cache_stats \
  segment_micro_location \
  segment_project segment_git segment_lines \
  segment_rate_limit_7d_stable \
  segment_worktree segment_duration"
```

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/segments/rate-limit-7d-stable.sh main.sh`
Expected: no output.

- [ ] **Step 4: Smoke-test zen vs. classic**

Zen mode:
```sh
CLAUDE_STATUSLINE_LAYOUT=zen COLUMNS=160 cat test/fixtures/zen-full.json | sh main.sh | tail -5
```
Expected: the output includes a 7d pill somewhere (currently will appear on workspace row since zen 3-row wiring isn't done yet — Task 20 completes it).

Classic mode:
```sh
COLUMNS=130 cat test/fixtures/rate-warming.json | sh main.sh
```
Expected: no 7d stable pill visible; inline 7d in the rate-limit segment instead.

- [ ] **Step 5: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 6: Commit**

```sh
git add lib/segments/rate-limit-7d-stable.sh main.sh
git commit -m "feat(rate-limit): add zen-only 7d stable ambient segment"
```

---

## Task 9: Implement `segment_alerts_slot`

**Files:**
- Create: `lib/segments/alerts-slot.sh`

Dependency: Tasks 2, 7, 8 complete.

- [ ] **Step 1: Write the segment**

Create `lib/segments/alerts-slot.sh`:

```sh
#!/bin/sh
# segments/alerts-slot.sh -- Priority-rotating alerts segment (Row 1 / session)
# Priority: cache-poor (<70%) > added-dirs > 7d-warning (zen only, >=70%)

segment_alerts_slot() {
  _as_hit=0

  # 1. Cache-poor
  _as_read=$(( sl_cache_read_tokens + 0 )) 2>/dev/null || _as_read=0
  if [ "$_as_read" -gt 0 ]; then
    _as_create=$(( sl_cache_create_tokens + 0 )) 2>/dev/null || _as_create=0
    _as_total=$(( _as_read + _as_create ))
    if [ "$_as_total" -gt 0 ]; then
      _as_ratio=$(( _as_read * 100 / _as_total ))
      if [ "$_as_ratio" -lt 70 ]; then
        _seg_icon="$GL_CACHE"
        _seg_content="cache ${_as_ratio}%"
        _seg_fg=$C_CACHE_POOR
        _as_hit=1
      fi
    fi
  fi

  # 2. Added dirs
  if [ "$_as_hit" -eq 0 ]; then
    _as_dirs=$(( sl_added_dirs_count + 0 )) 2>/dev/null || _as_dirs=0
    if [ "$_as_dirs" -gt 0 ]; then
      _seg_icon=""
      _seg_content="+${_as_dirs} dirs"
      _seg_fg=$C_DIM
      _as_hit=1
    fi
  fi

  # 3. 7d warning (zen-only)
  if [ "$_as_hit" -eq 0 ] && [ "$_sl_layout" = "zen" ]; then
    _as_7d=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _as_7d=-1
    if [ "$_as_7d" -ge 70 ]; then
      _seg_icon="$GL_WARN"
      _seg_content="7d ${_as_7d}%"
      _seg_attrs="bold"
      if [ "$_as_7d" -ge 85 ]; then
        _seg_fg=$C_DUR_CRIT
      else
        _seg_fg=$C_DUR_HIGH
      fi
      _as_hit=1
    fi
  fi

  [ "$_as_hit" -eq 0 ] && return 1

  _seg_weight="tertiary"
  _seg_min_tier="full"
  _seg_group="session"
  return 0
}
```

- [ ] **Step 2: Register segment in `SL_SEGMENTS`**

Edit `main.sh`. Final line now:

```sh
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_cache_stats segment_alerts_slot \
  segment_micro_location \
  segment_project segment_git segment_lines \
  segment_rate_limit_7d_stable \
  segment_worktree segment_duration"
```

(`segment_cache_stats` still present; removed in Task 12 where it's replaced fully.)

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/segments/alerts-slot.sh main.sh`
Expected: no output.

- [ ] **Step 4: Smoke-test**

Cache poor fixture:
```sh
COLUMNS=150 cat test/fixtures/rate-critical.json | sh main.sh
```
Expected: output contains `cache` somewhere on the session row (cache_read vs cache_create ratio should trigger).

- [ ] **Step 5: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 6: Commit**

```sh
git add lib/segments/alerts-slot.sh main.sh
git commit -m "feat(alerts-slot): add priority-rotating alerts segment (cache-poor, added-dirs, 7d-warning)"
```

---

## Task 10: Implement `segment_info_slot`

**Files:**
- Create: `lib/segments/info-slot.sh`

Dependency: Task 2 complete.

- [ ] **Step 1: Write the segment**

Create `lib/segments/info-slot.sh`:

```sh
#!/bin/sh
# segments/info-slot.sh -- Priority-rotating info segment (ambient / workspace fallback)
# Priority: output-style (non-default) > subdir > session-name > clock

segment_info_slot() {
  _is_hit=0

  # 1. Output style (non-default)
  if [ -n "$sl_output_style" ] && [ "$sl_output_style" != "default" ]; then
    _seg_content=". ${sl_output_style}"
    _seg_icon=""
    _is_hit=1
  fi

  # 2. Subdir drift
  if [ "$_is_hit" -eq 0 ] && [ -n "$sl_project_dir" ] && [ -n "$sl_cwd" ] && [ "$sl_cwd" != "$sl_project_dir" ]; then
    case "$sl_cwd" in
      "$sl_project_dir"/*)
        _is_rel="${sl_cwd#$sl_project_dir/}"
        # Truncate to 20 chars with left-ellipsis
        _is_len=${#_is_rel}
        if [ "$_is_len" -gt 20 ]; then
          _is_rel="...${_is_rel#???${_is_rel%??????????????????}}"
          # Simpler: take last 17 chars
          _is_rel="...$(printf '%s' "$_is_rel" | awk '{print substr($0, length($0)-16)}')"
        fi
        _seg_content="> ${_is_rel}"
        _seg_icon=""
        _is_hit=1
        ;;
    esac
  fi

  # 3. Session name
  if [ "$_is_hit" -eq 0 ] && [ -n "$sl_session_name" ]; then
    _seg_content="@${sl_session_name}"
    _seg_icon=""
    _is_hit=1
  fi

  # 4. Clock fallback
  if [ "$_is_hit" -eq 0 ]; then
    _seg_content="$(date +%H:%M)"
    _seg_icon="$GL_CLOCK"
    _is_hit=1
  fi

  _seg_weight="recessed"
  _seg_min_tier="full"
  _seg_group="ambient"
  _seg_group_fallback="workspace"
  _seg_attrs=""
  _seg_fg=""
  return 0
}
```

- [ ] **Step 2: Register segment in `SL_SEGMENTS`**

Edit `main.sh`. Insert `segment_info_slot` before `segment_rate_limit_7d_stable`:

```sh
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_cache_stats segment_alerts_slot \
  segment_micro_location \
  segment_project segment_git segment_info_slot segment_lines \
  segment_rate_limit_7d_stable \
  segment_worktree segment_duration"
```

- [ ] **Step 3: Support `_seg_group_fallback` in the render orchestrator**

Edit `lib/render.sh` in `render_row` (around the group gate, line 218). Replace:

```sh
    # Group gate (full tier only)
    if [ "$_sl_tier" = "full" ] && [ -n "$_rr_group" ] && [ "$_seg_group" != "$_rr_group" ]; then
      continue
    fi
```

With:

```sh
    # Group + fallback resolution
    _rr_eff_group="$_seg_group"
    if [ "$_sl_layout" != "zen" ] && [ -n "$_seg_group_fallback" ]; then
      _rr_eff_group="$_seg_group_fallback"
    fi

    # Group gate (multi-row tiers only)
    if [ "$_sl_tier" = "full" ] || [ "$_sl_tier" = "zen" ]; then
      if [ -n "$_rr_group" ] && [ "$_rr_eff_group" != "$_rr_group" ]; then
        continue
      fi
    fi
```

Also ensure `_seg_group_fallback` is reset at top of the iteration. In `render_row` (around line 203):

```sh
    # Reset segment metadata
    _seg_weight="" ; _seg_min_tier="" ; _seg_group=""
    _seg_group_fallback=""
    _seg_content="" ; _seg_icon="" ; _seg_bg="" ; _seg_fg=""
    _seg_attrs="" ; _seg_detail="" ; _seg_link_url=""
```

- [ ] **Step 4: Syntax check**

Run: `sh -n lib/segments/info-slot.sh lib/render.sh main.sh`
Expected: no output.

- [ ] **Step 5: Smoke-test**

```sh
COLUMNS=150 cat test/fixtures/rate-warming.json | sh main.sh
```
Expected: workspace row now contains `. Explanatory` (output-style fires because non-default).

```sh
COLUMNS=150 cat test/fixtures/rate-healthy.json | sh main.sh
```
Expected: workspace row now contains a clock `HH:MM` (output-style is default, no session-name, no subdir drift).

- [ ] **Step 6: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing (note: snapshot tests currently check row count + theme consistency, not exact content).

- [ ] **Step 7: Commit**

```sh
git add lib/segments/info-slot.sh lib/render.sh main.sh
git commit -m "feat(info-slot): add priority-rotating info segment with ambient/workspace fallback"
```

---

## Task 11: Retire `segment_cache_stats`

**Files:**
- Delete: `lib/segments/cache-stats.sh`
- Modify: `main.sh` (remove from `SL_SEGMENTS`)

Dependency: Task 9 complete (alerts_slot replaces it).

- [ ] **Step 1: Remove from `SL_SEGMENTS`**

Edit `main.sh`. Final list:

```sh
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_alerts_slot \
  segment_micro_location \
  segment_project segment_git segment_info_slot segment_lines \
  segment_rate_limit_7d_stable \
  segment_worktree segment_duration"
```

- [ ] **Step 2: Delete the file**

```sh
git rm lib/segments/cache-stats.sh
```

- [ ] **Step 3: Syntax check**

Run: `sh -n main.sh`
Expected: no output.

- [ ] **Step 4: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing. Cache hit ratio now appears only when `< 70%` via alerts-slot.

- [ ] **Step 5: Commit**

```sh
git add main.sh
git commit -m "refactor(cache-stats): retire always-on segment, replaced by alerts-slot gate"
```

---

## Task 12: Git segment — staged / unstaged / untracked split

**Files:**
- Modify: `lib/segments/git.sh`
- Modify: `lib/cache.sh` (extend git cache)

Dependency: Task 5 complete. Parallel-safe with Tasks 13-18 (different files).

- [ ] **Step 1: Read existing git cache code**

Run: `cat lib/cache.sh lib/segments/git.sh`
Confirm where `sl_is_dirty` is populated. The cache must additionally compute and export `sl_git_staged`, `sl_git_unstaged`, `sl_git_untracked`.

- [ ] **Step 2: Extend cache to compute split counts**

In `lib/cache.sh` inside the block that runs `git status --porcelain`, add computation:

```sh
  _cr_staged=$(printf '%s\n' "$_cr_porcelain" | awk '/^[MADRC]/ {n++} END {print n+0}')
  _cr_unstaged=$(printf '%s\n' "$_cr_porcelain" | awk '/^.[MADRC]/ {n++} END {print n+0}')
  _cr_untracked=$(printf '%s\n' "$_cr_porcelain" | awk '/^\?\?/ {n++} END {print n+0}')
```

Export them into the cache file format (append to the existing `printf` that writes the cache):

```sh
  printf "sl_is_dirty='%s'\nsl_ahead='%s'\nsl_behind='%s'\nsl_stash_count='%s'\nsl_git_staged='%s'\nsl_git_unstaged='%s'\nsl_git_untracked='%s'\n" \
    "$_cr_dirty" "$_cr_ahead" "$_cr_behind" "$_cr_stash" "$_cr_staged" "$_cr_unstaged" "$_cr_untracked" >> "$_cr_cache_file"
```

(Adapt to the existing exact format in cache.sh — use its quoting style.)

- [ ] **Step 3: Update `segment_git` to render the split**

In `lib/segments/git.sh`, after branch rendering, replace the dirty-dot block with:

```sh
  _gs_detail=""
  if [ -n "$sl_git_staged" ] && [ "$sl_git_staged" -gt 0 ]; then
    _gs_detail="${_gs_detail}+${sl_git_staged} "
  fi
  if [ -n "$sl_git_unstaged" ] && [ "$sl_git_unstaged" -gt 0 ]; then
    _gs_detail="${_gs_detail}-${sl_git_unstaged} "
  fi
  if [ -n "$sl_git_untracked" ] && [ "$sl_git_untracked" -gt 0 ]; then
    _gs_detail="${_gs_detail}?${sl_git_untracked} "
  fi
  # Then ahead/behind as today:
  [ "$sl_ahead" -gt 0 ] 2>/dev/null && _gs_detail="${_gs_detail}${GL_ARROW_UP}${sl_ahead} "
  [ "$sl_behind" -gt 0 ] 2>/dev/null && _gs_detail="${_gs_detail}${GL_ARROW_DOWN}${sl_behind} "
  _gs_detail="${_gs_detail% }"  # trim trailing space
  _seg_detail="$_gs_detail"
```

Remove the old `[ "$sl_is_dirty" = "1" ] && ...GL_DIRTY...` block; the split already conveys state.

- [ ] **Step 4: Syntax check**

Run: `sh -n lib/cache.sh lib/segments/git.sh`
Expected: no output.

- [ ] **Step 5: Smoke test (in this repo, which has uncommitted work)**

Run: `cat test/fixtures/full.json | sh main.sh`
Expected: git segment shows something like `main +2 ?1` or similar depending on current state.

- [ ] **Step 6: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 7: Commit**

```sh
git add lib/cache.sh lib/segments/git.sh
git commit -m "feat(git): split dirty indicator into staged/unstaged/untracked counts"
```

---

## Task 13: Git segment — conflicts override

**Files:**
- Modify: `lib/segments/git.sh`
- Modify: `lib/cache.sh` (detect merge/rebase state)

Dependency: Task 12 complete.

- [ ] **Step 1: Extend cache to detect merge/rebase state**

In `lib/cache.sh`, add a new function or extend existing `cache_refresh`:

```sh
  # Detect mid-merge / mid-rebase state
  _cr_git_op=""
  _cr_git_step=""
  if [ -f ".git/MERGE_HEAD" ]; then
    _cr_git_op="MERGING"
  elif [ -d ".git/rebase-merge" ]; then
    _cr_git_op="REBASING"
    if [ -r ".git/rebase-merge/msgnum" ] && [ -r ".git/rebase-merge/end" ]; then
      _cr_step=$(cat .git/rebase-merge/msgnum 2>/dev/null)
      _cr_total=$(cat .git/rebase-merge/end 2>/dev/null)
      _cr_git_step="${_cr_step}/${_cr_total}"
    fi
  elif [ -d ".git/rebase-apply" ]; then
    _cr_git_op="REBASING"
    if [ -r ".git/rebase-apply/next" ] && [ -r ".git/rebase-apply/last" ]; then
      _cr_step=$(cat .git/rebase-apply/next 2>/dev/null)
      _cr_total=$(cat .git/rebase-apply/last 2>/dev/null)
      _cr_git_step="${_cr_step}/${_cr_total}"
    fi
  fi
```

Export to cache file:

```sh
  printf "sl_git_op='%s'\nsl_git_step='%s'\n" "$_cr_git_op" "$_cr_git_step" >> "$_cr_cache_file"
```

- [ ] **Step 2: Override branch content in `segment_git` when in mid-op**

At the top of `segment_git`, after the "is this a git dir" check, add:

```sh
  if [ -n "$sl_git_op" ]; then
    _seg_icon="$GL_WARN"
    _seg_content="! ${sl_git_op}"
    [ -n "$sl_git_step" ] && _seg_content="${_seg_content} ${sl_git_step}"
    _seg_attrs="bold"
    _seg_fg=$C_CTX_CRIT_FG
    _seg_detail=""
    _seg_weight="secondary"
    _seg_min_tier="compact"
    _seg_group="workspace"
    return 0
  fi
```

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/cache.sh lib/segments/git.sh`
Expected: no output.

- [ ] **Step 4: Simulate rebase state and verify**

```sh
tmpdir=$(mktemp -d)
cd "$tmpdir"
git init -q
mkdir -p .git/rebase-merge
echo 2 > .git/rebase-merge/msgnum
echo 5 > .git/rebase-merge/end
cat - <<'EOF' | sh /path/to/claude-statusline/main.sh
{"cwd":"'"$tmpdir"'","model":{"id":"claude-opus-4-7","display_name":"Claude Opus"}}
EOF
cd - && rm -rf "$tmpdir"
```

Expected: output shows `! REBASING 2/5` in the git segment.

(Replace `/path/to/claude-statusline` with the actual absolute repo path.)

- [ ] **Step 5: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 6: Commit**

```sh
git add lib/cache.sh lib/segments/git.sh
git commit -m "feat(git): add conflicts override for mid-merge/rebase state"
```

---

## Task 14: Git segment — fork badge

**Files:**
- Modify: `lib/segments/git.sh`
- Modify: `lib/cache.sh` (detect fork state)

Dependency: Task 12 complete. Can run in parallel with Task 13.

- [ ] **Step 1: Extend cache to detect fork**

In `lib/cache.sh` inside the git block:

```sh
  _cr_fork=0
  _cr_origin=$(git config --get remote.origin.url 2>/dev/null)
  _cr_upstream=$(git config --get remote.upstream.url 2>/dev/null)
  if [ -n "$_cr_origin" ] && [ -n "$_cr_upstream" ] && [ "$_cr_origin" != "$_cr_upstream" ]; then
    _cr_fork=1
  fi
```

Export:

```sh
  printf "sl_git_fork='%s'\n" "$_cr_fork" >> "$_cr_cache_file"
```

- [ ] **Step 2: Render fork badge in `segment_git`**

In the detail-building block, after ahead/behind, add:

```sh
  if [ "$sl_git_fork" = "1" ]; then
    _gs_detail="${_gs_detail} ${GL_FORK} fork"
  fi
  _seg_detail="$_gs_detail"
```

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/cache.sh lib/segments/git.sh`
Expected: no output.

- [ ] **Step 4: Simulate fork state**

```sh
tmpdir=$(mktemp -d); cd "$tmpdir"; git init -q
git config remote.origin.url https://github.com/me/fork.git
git config remote.upstream.url https://github.com/orig/repo.git
echo '{"cwd":"'"$tmpdir"'","model":{"id":"claude-opus-4-7","display_name":"Claude Opus"}}' | sh /path/to/claude-statusline/main.sh
cd - && rm -rf "$tmpdir"
```

Expected: git segment shows a `fork` suffix.

- [ ] **Step 5: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 6: Commit**

```sh
git add lib/cache.sh lib/segments/git.sh
git commit -m "feat(git): add fork badge when origin != upstream"
```

---

## Task 15: Duration segment — API-time suffix

**Files:**
- Modify: `lib/segments/duration.sh`

Dependency: Task 2 complete. Parallel-safe with Tasks 12, 13, 14, 16, 17, 18.

- [ ] **Step 1: Extend the segment**

In `lib/segments/duration.sh`, inside the rendering of full/compact tier, append API-time when available:

```sh
  # After computing the main duration string (e.g. "34m"):
  _du_api_ms=$(( sl_api_duration_ms + 0 )) 2>/dev/null || _du_api_ms=0
  if [ "$_sl_tier" = "full" ] || [ "$_sl_tier" = "zen" ]; then
    if [ "$_du_api_ms" -ge 60000 ] && [ "$_du_api_ms" -lt "$(( sl_duration_ms + 0 ))" ]; then
      _du_api_min=$(( _du_api_ms / 60000 ))
      _seg_detail="(api ${_du_api_min}m)"

      # Escalation: if api_pct < 15 after 20 min, medium-color the detail.
      _du_wall_min=$(( sl_duration_ms / 60000 ))
      if [ "$_du_wall_min" -ge 20 ]; then
        _du_api_pct=$(( _du_api_ms * 100 / ( sl_duration_ms + 1 ) ))
        if [ "$_du_api_pct" -lt 15 ]; then
          _seg_fg=$C_DUR_MED
        fi
      fi
    fi
  fi
```

- [ ] **Step 2: Syntax check**

Run: `sh -n lib/segments/duration.sh`
Expected: no output.

- [ ] **Step 3: Smoke-test**

```sh
COLUMNS=150 cat test/fixtures/rate-warming.json | sh main.sh
```
Expected: duration segment shows `34m (api 8m)`.

- [ ] **Step 4: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 5: Commit**

```sh
git add lib/segments/duration.sh
git commit -m "feat(duration): append API-time detail suffix on full tier"
```

---

## Task 16: Context segment — V1 pluggable gauge styles

**Files:**
- Modify: `lib/segments/context.sh`
- Modify: `lib/render.sh` (add `ctx_gauge_render` helper)

Dependency: Task 5 complete. Parallel-safe with Tasks 12-15, 17, 18.

- [ ] **Step 1: Add helper to `lib/render.sh`**

Append to `lib/render.sh`:

```sh
# --- Context gauge renderer ---
# Produces a 5-cell gauge based on CLAUDE_STATUSLINE_CTX_GAUGE.
# Args: output_var, pct (0-100)
ctx_gauge_render() {
  _cg_out_var="$1"
  _cg_pct="$2"
  _cg_filled=$(( _cg_pct / 20 ))
  [ "$_cg_filled" -gt 5 ] && _cg_filled=5
  _cg_empty=$(( 5 - _cg_filled ))
  _cg_result=""
  case "${CLAUDE_STATUSLINE_CTX_GAUGE:-dots}" in
    blocks)
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_filled" ]; do _cg_result="${_cg_result}${GL_BLK_FILLED}"; _cg_i=$((_cg_i+1)); done
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_empty"  ]; do _cg_result="${_cg_result}${GL_BLK_EMPTY}";  _cg_i=$((_cg_i+1)); done
      ;;
    pips)
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_filled" ]; do _cg_result="${_cg_result}${GL_PIP_FILLED} "; _cg_i=$((_cg_i+1)); done
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_empty"  ]; do _cg_result="${_cg_result}${GL_PIP_EMPTY} ";  _cg_i=$((_cg_i+1)); done
      ;;
    braille)
      # Map pct into 9 buckets (BRL_0..BRL_8) stretched across 3 cells
      _cg_n=$(( _cg_pct * 9 / 100 ))
      [ "$_cg_n" -gt 8 ] && _cg_n=8
      eval "_cg_result=\$GL_BRL_${_cg_n}\$GL_BRL_${_cg_n}\$GL_BRL_${_cg_n}"
      ;;
    dots|*)
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_filled" ]; do _cg_result="${_cg_result}${GL_DOT_FILLED} "; _cg_i=$((_cg_i+1)); done
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_empty"  ]; do _cg_result="${_cg_result}${GL_DOT_EMPTY} ";  _cg_i=$((_cg_i+1)); done
      _cg_result="${_cg_result% }"
      ;;
  esac
  eval "$_cg_out_var=\$_cg_result"
}
```

- [ ] **Step 2: Use the helper in `lib/segments/context.sh`**

Replace the existing dot-building block (lines ~47-51) with:

```sh
    ctx_gauge_render _cx_dots "$_cx_pct"
```

- [ ] **Step 3: Syntax check**

Run: `sh -n lib/render.sh lib/segments/context.sh`
Expected: no output.

- [ ] **Step 4: Smoke-test all four styles**

```sh
for s in dots blocks pips braille; do
  echo "--- $s ---"
  CLAUDE_STATUSLINE_CTX_GAUGE=$s COLUMNS=150 cat test/fixtures/mid.json | sh main.sh | head -1
done
```
Expected: visibly different gauges per style.

- [ ] **Step 5: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 6: Commit**

```sh
git add lib/render.sh lib/segments/context.sh
git commit -m "feat(ctx-gauge): add pluggable context gauge styles (dots/blocks/braille/pips)"
```

---

## Task 17: Burn-rate segment — braille sparkline tail

**Files:**
- Modify: `lib/segments/burn-rate.sh`

Dependency: Tasks 4, 5 complete. Parallel-safe with Tasks 12-16, 18.

- [ ] **Step 1: Extend the segment**

In `lib/segments/burn-rate.sh`, after computing tokens/minute, push into the ring buffer and render a tail:

```sh
  # Push sample and read back
  sparkline_push "$_br_tokens_per_min"
  _br_history=$(sparkline_read)

  # Render sparkline tail if history has >= 4 samples
  _br_spark=""
  _br_n=$(printf '%s\n' "$_br_history" | tr ',' '\n' | wc -l | tr -d ' ')
  if [ "$_br_n" -ge 4 ] && [ "$_sl_tier" != "micro" ] && [ "$_sl_tier" != "compact" ]; then
    # Find max
    _br_max=$(printf '%s\n' "$_br_history" | tr ',' '\n' | sort -n | tail -1)
    [ "$_br_max" -lt 1 ] && _br_max=1
    _br_spark=" "
    OIFS=$IFS; IFS=,
    for _v in $_br_history; do
      _br_bucket=$(( _v * 8 / _br_max ))
      [ "$_br_bucket" -gt 8 ] && _br_bucket=8
      eval "_br_spark=\"\${_br_spark}\$GL_BRL_${_br_bucket}\""
    done
    IFS=$OIFS
  fi

  _seg_content="${_br_tokens_per_min}k/m${_br_spark}"
```

Replace whatever `_seg_content` is today with this new line. Read the existing file to find the exact assignment.

- [ ] **Step 2: Syntax check**

Run: `sh -n lib/segments/burn-rate.sh`
Expected: no output.

- [ ] **Step 3: Smoke test multiple renders to build history**

```sh
for i in 1 2 3 4 5; do
  COLUMNS=150 cat test/fixtures/mid.json | sh main.sh > /dev/null
  sleep 0.1
done
COLUMNS=150 cat test/fixtures/mid.json | sh main.sh | head -1
```
Expected: burn-rate segment now includes braille chars at the tail.

- [ ] **Step 4: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 5: Commit**

```sh
git add lib/segments/burn-rate.sh
git commit -m "feat(burn-rate): add braille sparkline tail using ring-buffer cache"
```

---

## Task 18: Enforce recessed weight for ambient group

**Files:**
- Modify: `lib/render.sh` (add weight guard)

Dependency: Task 10 complete (ambient group exists). Parallel-safe with Tasks 12-17.

- [ ] **Step 1: Add the guard**

In `lib/render.sh`, inside `render_row`, right after the group-fallback resolution block (added in Task 10), add:

```sh
    # Ambient group hard-enforces recessed weight
    if [ "$_seg_group" = "ambient" ] && [ "$_seg_weight" != "recessed" ]; then
      _seg_weight="recessed"
    fi
```

- [ ] **Step 2: Syntax check**

Run: `sh -n lib/render.sh`
Expected: no output.

- [ ] **Step 3: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 4: Commit**

```sh
git add lib/render.sh
git commit -m "feat(render): enforce recessed weight for ambient group"
```

---

## Task 19: Wire zen 3-row layout in `main.sh`

**Files:**
- Modify: `main.sh` (bottom render block)

Dependency: Tasks 7-11, 18 complete.

- [ ] **Step 1: Extend the render block**

Replace the final render block (lines 90-105) with:

```sh
# --- Render ---
if [ "$_sl_tier" = "zen" ]; then
  reset_row
  render_row "session"
  row1="$sl_row"

  reset_row
  render_row "workspace"
  row2="$sl_row"

  reset_row
  render_row "ambient"
  row3="$sl_row"

  printf '%b\n' "$row1"
  printf '%b\n' "$row2"
  printf '%b\n' "$row3"
elif [ "$_sl_tier" = "full" ]; then
  reset_row
  render_row "session"
  row1="$sl_row"

  reset_row
  render_row "workspace"
  row2="$sl_row"

  printf '%b\n' "$row1"
  printf '%b\n' "$row2"
else
  reset_row
  render_row ""
  printf '%b\n' "$sl_row"
fi
```

- [ ] **Step 2: Syntax check**

Run: `sh -n main.sh`
Expected: no output.

- [ ] **Step 3: Render zen mode**

```sh
CLAUDE_STATUSLINE_LAYOUT=zen COLUMNS=160 cat test/fixtures/zen-full.json | sh main.sh
```
Expected: 3 lines of output.

- [ ] **Step 4: Render default (classic full)**

```sh
COLUMNS=130 cat test/fixtures/full.json | sh main.sh
```
Expected: 2 lines, unchanged behavior.

- [ ] **Step 5: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 6: Commit**

```sh
git add main.sh
git commit -m "feat(zen): wire 3-row render block for zen layout"
```

---

## Task 20: Capsule cap shape (V3)

**Files:**
- Modify: `lib/render.sh` (emit caps at row boundaries)

Dependency: Task 5 complete.

- [ ] **Step 1: Wire cap-shape selection in `detect_capabilities`**

In `lib/render.sh`, at the bottom of the Nerd-Font branch of `detect_capabilities`, add:

```sh
  # Cap shape selection (capsule vs. powerline triangle)
  case "${CLAUDE_STATUSLINE_CAP_STYLE:-powerline}" in
    capsule)
      SL_USE_CAPSULE=1
      ;;
    *)
      SL_USE_CAPSULE=0
      ;;
  esac
```

- [ ] **Step 2: Emit left cap at start of row**

In `render_row`, right before the segment loop, add a left-cap emit if first segment will be on a BG:

```sh
  # Remember cap state for this row
  _rr_cap_emit=0
  if [ "${SL_USE_CAPSULE:-0}" -eq 1 ]; then
    _rr_cap_emit=1
  fi
```

Then inside `emit_segment` (or at the point where the first segment is added), if `_rr_cap_emit=1` and `sl_prev_bg` is empty, prepend:

```sh
  if [ "${SL_USE_CAPSULE:-0}" -eq 1 ] && [ -z "$sl_prev_bg" ]; then
    sl_row="\033[38;5;${_es_bg}m${GL_CAP_LEFT}\033[0m"
  fi
```

- [ ] **Step 3: Emit right cap at end of row**

Extend `emit_end`:

```sh
emit_end() {
  if [ -n "$sl_prev_bg" ]; then
    if [ "${SL_USE_CAPSULE:-0}" -eq 1 ]; then
      sl_row="${sl_row}${SL_RST}\033[38;5;${sl_prev_bg}m${GL_CAP_RIGHT}${SL_RST}"
    else
      sl_row="${sl_row}${SL_RST}\033[38;5;${sl_prev_bg}m${GL_POWERLINE}${SL_RST}"
    fi
  fi
}
```

- [ ] **Step 4: Syntax check**

Run: `sh -n lib/render.sh`
Expected: no output.

- [ ] **Step 5: Compare visual output**

```sh
CLAUDE_STATUSLINE_CAP_STYLE=capsule COLUMNS=130 cat test/fixtures/full.json | sh main.sh | head -1 > /tmp/capsule.txt
CLAUDE_STATUSLINE_CAP_STYLE=powerline COLUMNS=130 cat test/fixtures/full.json | sh main.sh | head -1 > /tmp/powerline.txt
diff /tmp/capsule.txt /tmp/powerline.txt
rm -f /tmp/capsule.txt /tmp/powerline.txt
```
Expected: first bytes differ (capsule has `U+E0B6` at start, powerline does not).

- [ ] **Step 6: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 7: Commit**

```sh
git add lib/render.sh
git commit -m "feat(render): add capsule cap shape via CLAUDE_STATUSLINE_CAP_STYLE"
```

---

## Task 21: Minimalist mode

**Files:**
- Modify: `lib/render.sh` (strip icon/label in `render_row`)
- Modify: all segment files that render labels

Dependency: Tasks 7-17 complete (all segments exist to adapt).

- [ ] **Step 1: Introduce a minimalist flag**

In `lib/render.sh` at the top of `render_row`, after capability detection values are read:

```sh
  _rr_minimal="${CLAUDE_STATUSLINE_MINIMAL:-0}"
```

- [ ] **Step 2: Skip icon prefix when minimal is on**

In the icon-prefix block:

```sh
    _rr_icon=""
    if [ "$_rr_minimal" != "1" ] && [ "$SL_CAP_NERD" -eq 1 ] && [ -n "$_seg_icon" ] && [ "$_sl_tier" != "micro" ]; then
      _rr_icon="${_seg_icon} "
    fi
```

- [ ] **Step 3: Adapt segment-specific labels**

In segments that emit label words, wrap their label text in a check. Example in `lib/segments/rate-limit.sh` in the ember branch:

```sh
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_content="${_rl_time} ${_rl_5h}%"   # no labels, no icon-like glyph duplication
  fi
```

For `lib/segments/alerts-slot.sh`:

```sh
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    # Strip "cache " prefix, "+" prefix for dirs, etc. Just keep value + state color.
    _seg_content=$(printf '%s' "$_seg_content" | sed 's/^cache //;s/^+//;s/ dirs//;s/^7d //')
  fi
```

For `lib/segments/duration.sh`:

```sh
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_detail=""
  fi
```

Apply similar stripping where a segment emits a word-label. Keep color, drop text labels.

- [ ] **Step 4: Syntax check**

Run: `sh -n lib/render.sh lib/segments/rate-limit.sh lib/segments/alerts-slot.sh lib/segments/duration.sh`
Expected: no output.

- [ ] **Step 5: Smoke-test**

```sh
CLAUDE_STATUSLINE_MINIMAL=1 COLUMNS=150 cat test/fixtures/rate-warming.json | sh main.sh
```
Expected: output is visibly flatter — no icons, no word labels.

- [ ] **Step 6: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 7: Commit**

```sh
git add lib/render.sh lib/segments/rate-limit.sh lib/segments/alerts-slot.sh lib/segments/duration.sh
git commit -m "feat(minimal): strip icons and word-labels when CLAUDE_STATUSLINE_MINIMAL=1"
```

---

## Task 22: Per-segment enable/disable via `CLAUDE_STATUSLINE_SEGMENTS`

**Files:**
- Modify: `main.sh`

Dependency: Tasks 7-11 complete.

- [ ] **Step 1: Add env-var override logic**

In `main.sh`, after the existing `SL_SEGMENTS=...` assignment, add:

```sh
# Per-segment override (comma-separated basenames)
if [ -n "${CLAUDE_STATUSLINE_SEGMENTS:-}" ]; then
  _sl_override=""
  OIFS=$IFS
  IFS=,
  for _name in $CLAUDE_STATUSLINE_SEGMENTS; do
    _name=$(printf '%s' "$_name" | tr -d ' ')
    [ -z "$_name" ] && continue
    _sl_override="${_sl_override} segment_${_name}"
  done
  IFS=$OIFS
  [ -n "$_sl_override" ] && SL_SEGMENTS="$_sl_override"
fi
```

- [ ] **Step 2: Syntax check**

Run: `sh -n main.sh`
Expected: no output.

- [ ] **Step 3: Smoke-test**

```sh
CLAUDE_STATUSLINE_SEGMENTS="model,context,rate_limit" COLUMNS=150 cat test/fixtures/rate-warming.json | sh main.sh
```
Expected: line contains only model, context, rate-limit (no git, no duration, no project).

- [ ] **Step 4: Run tests**

Run: `sh test/run.sh --check`
Expected: 48 passing.

- [ ] **Step 5: Commit**

```sh
git add main.sh
git commit -m "feat(main): support CLAUDE_STATUSLINE_SEGMENTS for per-segment enable/disable"
```

---

## Task 23: Documentation — `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

Dependency: Tasks 1-22 complete. Parallel-safe with 24, 25, 26.

- [ ] **Step 1: Update the architecture sections**

Edit `CLAUDE.md` to reflect v2:

- "Three-Tier Adaptive Layout" -> "Four-Tier Adaptive Layout" with zen added, table updated
- Segment table: add `rate_limit`, `rate_limit_7d_stable`, `alerts_slot`, `info_slot`. Remove `cache_stats`.
- "Segment Contract": add `_seg_group_fallback` field + `ambient` group value + `zen` min_tier value
- "Variable Naming Conventions": add new `sl_*` runtime vars and `_sl_layout` + new `GL_*` families
- "Segment Registration Order": update to final v2 list
- "JSON Input Schema": add the new fields (rate_limits, output_style, session_name, added_dirs, api_duration, project_dir)
- "Adding a New Segment": update instructions and template to mention fallback group
- "Testing": add the new env-var matrix (LAYOUT, RATE_STYLE, CTX_GAUGE, CAP_STYLE, SEGMENTS, MINIMAL)

- [ ] **Step 2: Commit**

```sh
git add CLAUDE.md
git commit -m "docs(claude): update architecture reference for v2 layout, segments, env vars"
```

---

## Task 24: Documentation — `README.md`

**Files:**
- Modify: `README.md`

Dependency: Tasks 1-22 complete. Parallel-safe with 23, 25, 26.

- [ ] **Step 1: Add zen mode subsection**

Add a new section after "Adapts to Your Terminal":

```markdown
### Zen layout

For wide terminals (>=140 cols), opt into a 3-row heavy-top layout:

\`\`\`sh
export CLAUDE_STATUSLINE_LAYOUT=zen
\`\`\`

Row 1 is your dynamic "glance" strip - model, context, rate-limit, burn-rate, alerts. Row 2 is the workspace view. Row 3 is recessed ambient info (7d rate, output-style, subdir, session-name, clock).
```

- [ ] **Step 2: Update the feature table**

Update the segment feature table:
- Replace "Cache" with "Rate-limit" as a headline segment
- Add "Adaptive slot" row explaining the rotation
- Note the retired always-on cache segment

- [ ] **Step 3: Add config file example**

After the env-var section:

```markdown
### Config file

Prefer a config file to managing many env vars:

\`\`\`sh
# ~/.config/claude-statusline/config.sh
CLAUDE_STATUSLINE_THEME=dracula
CLAUDE_STATUSLINE_LAYOUT=zen
CLAUDE_STATUSLINE_RATE_STYLE=ember
CLAUDE_STATUSLINE_CTX_GAUGE=blocks
\`\`\`

The file is sourced at startup. All `CLAUDE_STATUSLINE_*` variables are honored.
```

- [ ] **Step 4: Commit**

```sh
git add README.md
git commit -m "docs(readme): add zen mode section, rate-limit feature, config-file example"
```

---

## Task 25: Documentation — `CONTRIBUTING.md`

**Files:**
- Modify: `CONTRIBUTING.md`

Dependency: Tasks 1-22 complete. Parallel-safe with 23, 24, 26.

- [ ] **Step 1: Document new segment contract fields**

Edit `CONTRIBUTING.md` to add:

- A subsection "Row groups in zen mode" explaining `ambient` and `_seg_group_fallback`
- Update the "Adding a segment" template to include fallback and min_tier=zen
- Add a small block on the priority-rotation pattern used by `alerts_slot` and `info_slot`
- Note that `_seg_group=ambient` segments are force-demoted to recessed weight

- [ ] **Step 2: Commit**

```sh
git add CONTRIBUTING.md
git commit -m "docs(contributing): document ambient group, fallback field, and slot rotation pattern"
```

---

## Task 26: Documentation — new `CONFIG.md`

**Files:**
- Create: `docs/CONFIG.md`

Dependency: Tasks 1-22 complete. Parallel-safe with 23, 24, 25.

- [ ] **Step 1: Create the file**

Create `docs/CONFIG.md`:

```markdown
# Configuration

All configuration is via environment variables, which can live in a shell config file sourced at startup.

## Config file

Default path: `~/.config/claude-statusline/config.sh`. Override with `CLAUDE_STATUSLINE_CONFIG_FILE=/other/path.sh`.

The file is sourced as POSIX shell at the top of `main.sh`. Only assign `CLAUDE_STATUSLINE_*` variables; do not run side-effect commands.

Example:

\`\`\`sh
CLAUDE_STATUSLINE_THEME=dracula
CLAUDE_STATUSLINE_LAYOUT=zen
CLAUDE_STATUSLINE_RATE_STYLE=ember
CLAUDE_STATUSLINE_CTX_GAUGE=blocks
\`\`\`

## Environment variables

| Name                             | Default                                     | Values                                    | Effect                                                                 |
|----------------------------------|---------------------------------------------|-------------------------------------------|------------------------------------------------------------------------|
| `CLAUDE_STATUSLINE_THEME`        | `catppuccin-mocha`                          | any file under `lib/themes/`              | theme selection                                                        |
| `CLAUDE_STATUSLINE_NERD_FONT`    | `1`                                         | `0` / `1`                                 | enable Nerd Font glyphs; falls back to ASCII when 0                    |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`| `95`                                        | 50-99                                     | target % for compaction ETA                                            |
| `CLAUDE_STATUSLINE_LAYOUT`       | `classic`                                   | `classic` / `zen`                         | 2-row default vs. 3-row zen (requires width >= 140 for zen)            |
| `CLAUDE_STATUSLINE_RATE_STYLE`   | `ember`                                     | `ember` / `bar` / `pill` / `minimal`      | rate-limit segment preset                                              |
| `CLAUDE_STATUSLINE_CTX_GAUGE`    | `dots`                                      | `dots` / `blocks` / `braille` / `pips`    | context gauge style                                                    |
| `CLAUDE_STATUSLINE_CAP_STYLE`    | `powerline`                                 | `powerline` / `capsule`                   | row-end cap shape                                                      |
| `CLAUDE_STATUSLINE_SEGMENTS`     | (unset)                                     | comma list of segment basenames           | overrides the default segment list                                     |
| `CLAUDE_STATUSLINE_MINIMAL`      | `0`                                         | `0` / `1`                                 | strip icons + word labels (color preserved)                            |
| `CLAUDE_STATUSLINE_CONFIG_FILE`  | `$HOME/.config/claude-statusline/config.sh` | absolute path                             | config file location                                                   |

## Adaptive slots

Two "slot" segments rotate conditionally:

**`alerts_slot` (Row 1, session group, priority order):**

1. `cache-poor`: cache hit ratio < 70% and cache is active
2. `added-dirs`: at least one dir added via `/add-dir`
3. `7d-warning`: zen-only; 7d rate used >= 70%

**`info_slot` (Row 3 ambient in zen, workspace in classic, priority order):**

1. `output-style`: when `/output-style` is non-default
2. `subdir`: cwd is a descendant of project_dir
3. `session-name`: when `/session rename` was used
4. `clock`: always-true fallback

Both segments emit only the first match, or nothing if nothing fires (alerts) or the clock (info).
```

- [ ] **Step 2: Commit**

```sh
git add docs/CONFIG.md
git commit -m "docs(config): add configuration reference covering env vars and slot rotation"
```

---

## Task 27: Performance benchmark

**Files:**
- Modify: `test/run.sh` (add a benchmark target)

Dependency: Tasks 7-22 complete.

- [ ] **Step 1: Add a benchmark block to `test/run.sh`**

Add a new flag `--bench` to `test/run.sh` that runs the zen-full fixture 10 times and reports average wall time, failing if > 50ms on macOS / 30ms on Linux:

```sh
if [ "${1:-}" = "--bench" ]; then
  _thr_ms=50
  uname -s | grep -qi linux && _thr_ms=30
  _tot_ms=0
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    _start=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
    COLUMNS=150 CLAUDE_STATUSLINE_LAYOUT=zen cat test/fixtures/zen-full.json | sh main.sh > /dev/null
    _end=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
    _delta_ms=$(( (_end - _start) / 1000000 ))
    _tot_ms=$(( _tot_ms + _delta_ms ))
  done
  _avg_ms=$(( _tot_ms / 10 ))
  echo "Average render: ${_avg_ms}ms (threshold: ${_thr_ms}ms)"
  if [ "$_avg_ms" -gt "$_thr_ms" ]; then
    echo "FAIL: exceeds threshold"
    exit 1
  fi
  echo "PASS"
  exit 0
fi
```

- [ ] **Step 2: Run benchmark**

Run: `sh test/run.sh --bench`
Expected: `PASS` with average render under 50ms on macOS (or 30ms on Linux).

- [ ] **Step 3: Commit**

```sh
git add test/run.sh
git commit -m "test(bench): add --bench target with 50ms/30ms render thresholds"
```

---

## Task 28: Final integration — full `--check` run across all env-var permutations

**Files:**
- Modify: `test/run.sh` (extend the --check matrix)

Dependency: Tasks 1-27 complete.

- [ ] **Step 1: Extend `--check` to include new fixtures and env vars**

In `test/run.sh`, update the `--check` block to iterate over:

- Scenarios: existing (`minimal`, `mid`, `full`, `critical`) + new (`rate-healthy`, `rate-warming`, `rate-critical`, `zen-full`)
- Layouts: `classic` (every scenario) + `zen` (zen-full only)
- Tiers: `full`, `compact`, `micro` per classic; `zen` for zen-full
- Themes: all 4 existing

The exact loop structure depends on the existing `--check` implementation — read it first.

- [ ] **Step 2: Run expanded check**

Run: `sh test/run.sh --check`
Expected: all tests pass. The new total should be around 96+ tests.

- [ ] **Step 3: Run under alternate shells**

```sh
sh test/run.sh --check --shell dash
sh test/run.sh --check --shell bash
sh test/run.sh --check --shell zsh
```
Expected: all pass.

- [ ] **Step 4: Run benchmark**

Run: `sh test/run.sh --bench`
Expected: PASS.

- [ ] **Step 5: Final commit**

```sh
git add test/run.sh
git commit -m "test(integration): extend --check matrix with v2 fixtures and env-var permutations"
```

- [ ] **Step 6: Summary check**

Run:
```sh
git log --oneline feat/v2-statusline-enhancements ^main | wc -l
sh test/run.sh --check | tail -1
sh test/run.sh --bench | tail -2
```

Expected: commit count >= 26, tests pass, benchmark passes. Ready to open a PR.

---

## Self-Review Checklist

Run the following sanity checks before handing off:

1. **Spec coverage:** Every section in `docs/specs/2026-04-17-statusline-v2-enhancements-design.md` has at least one task covering it. In-scope items 1-13 all mapped:
   - Spec §4.1 rate_limit -> Task 7
   - Spec §4.2 alerts_slot -> Task 9
   - Spec §4.3 info_slot -> Task 10
   - Spec §4.4 JSON fields -> Task 2
   - Spec §5.1 sparkline -> Tasks 4 + 17
   - Spec §5.2 git upgrades -> Tasks 12, 13, 14
   - Spec §5.3 duration -> Task 15
   - Spec §5.4 ctx gauge -> Task 16
   - Spec §6 config system -> Tasks 3, 22, 26
   - Spec §7 zen layout -> Tasks 8, 18, 19
   - Spec §7.4 cap style -> Task 20
   - Spec §8 testing -> Tasks 6, 27, 28
   - Spec §11 docs -> Tasks 23, 24, 25, 26
2. **Placeholder scan:** no `TODO`, `TBD`, `handle edge cases`, or `fill in details` remaining.
3. **Type consistency:** every segment function name, env var, variable, glyph variable, cache-file path, and run-time var is spelled consistently with the contracts section (C1-C10).
4. **Dependency graph:** tasks that must run sequentially are marked with "Dependency:" and no backward references to uncreated files.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-04-17-statusline-v2-implementation.md`. Two execution options:

1. **Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fast iteration. Use `superpowers:subagent-driven-development`.
2. **Inline Execution** - execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

Which approach?
