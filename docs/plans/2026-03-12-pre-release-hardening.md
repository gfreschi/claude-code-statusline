# Pre-Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all code review findings (2 critical, 5 important, 6 suggestions) and add standard open-source project files before the first public release.

**Architecture:** All changes are localized edits -- no new architecture or abstractions. Security fixes in `cache.sh`, edge-case guards in segments, documentation cleanup in README, and standard open-source files (CONTRIBUTING, .editorconfig).

**Tech Stack:** POSIX sh, jq

---

## Chunk 1: Critical Security Fixes

### Task 1: Fix shell injection in cache file writes

The cache file writes `sl_branch` and `sl_github_base_url` using double quotes. A branch name containing `"` (valid in git) breaks out of the quotes and executes arbitrary code when the cache is sourced.

**Files:**
- Modify: `cache.sh:86-97`

- [ ] **Step 1: Write test case for the injection vector**

Create a manual test to verify the vulnerability exists. Run from repo root:

```sh
# Create a test branch name with double quotes
_test_branch='feat/test"$(echo INJECTED)"rest'
# Simulate the vulnerable printf
printf 'sl_branch="%s"\n' "$_test_branch"
# Expected output showing the injection:
# sl_branch="feat/test"$(echo INJECTED)"rest"
```

Verify the output shows unescaped quotes that would allow injection.

- [ ] **Step 2: Replace double-quoted writes with single-quoted, properly escaped values**

In `cache.sh`, replace the cache write block (lines 86-97) with single-quote-escaped writes. The approach: for string values, replace every `'` in the value with `'\''` (end single-quote, escaped literal quote, start single-quote), then wrap in single quotes. Numeric values stay unquoted since they're already sanitized via `%d`.

Replace:

```sh
  # Write cache atomically
  _cr_tmp="${_cr_cache}.$$"
  {
    printf 'sl_branch="%s"\n' "$sl_branch"
    printf 'sl_is_detached=%d\n' "$sl_is_detached"
    printf 'sl_is_dirty=%d\n' "$sl_is_dirty"
    printf 'sl_ahead=%d\n' "$sl_ahead"
    printf 'sl_behind=%d\n' "$sl_behind"
    printf 'sl_stash_count=%d\n' "$sl_stash_count"
    printf 'sl_github_base_url="%s"\n' "$sl_github_base_url"
  } > "$_cr_tmp"
  mv "$_cr_tmp" "$_cr_cache"
```

With:

```sh
  # Write cache atomically
  # String values: single-quote with proper escaping to prevent injection
  # Numeric values: %d already sanitizes to digits only
  _cr_tmp="${_cr_cache}.$$"
  _cr_sq_branch=$(printf '%s' "$sl_branch" | sed "s/'/'\\\\''/g")
  _cr_sq_url=$(printf '%s' "$sl_github_base_url" | sed "s/'/'\\\\''/g")
  {
    printf "sl_branch='%s'\n" "$_cr_sq_branch"
    printf 'sl_is_detached=%d\n' "$sl_is_detached"
    printf 'sl_is_dirty=%d\n' "$sl_is_dirty"
    printf 'sl_ahead=%d\n' "$sl_ahead"
    printf 'sl_behind=%d\n' "$sl_behind"
    printf 'sl_stash_count=%d\n' "$sl_stash_count"
    printf "sl_github_base_url='%s'\n" "$_cr_sq_url"
  } > "$_cr_tmp"
  mv "$_cr_tmp" "$_cr_cache"
```

- [ ] **Step 3: Verify the fix**

Run the same test from Step 1, this time sourcing the output to confirm no injection:

```sh
# Simulate the fixed printf with a malicious branch name
_test_branch='feat/test"$(echo INJECTED)"rest'
_sq=$(printf '%s' "$_test_branch" | sed "s/'/'\\\\''/g")
printf "sl_branch='%s'\n" "$_sq"
# Expected: sl_branch='feat/test"$(echo INJECTED)"rest'
# The double quotes are now harmless inside single quotes
```

Also test with a branch containing single quotes:

```sh
_test_branch="feat/test'quoted"
_sq=$(printf '%s' "$_test_branch" | sed "s/'/'\\\\''/g")
printf "sl_branch='%s'\n" "$_sq"
# Expected: sl_branch='feat/test'\''quoted'
```

- [ ] **Step 4: Run `sh -n cache.sh` syntax check**

```sh
sh -n cache.sh
```

Expected: no output (clean parse).

- [ ] **Step 5: Run test harness to verify cache integration**

```sh
sh test.sh full && sh test.sh minimal
```

Expected: renders correctly on all tiers.

---

### Task 2: Use per-user cache directory instead of world-readable /tmp

Cache files are created at `/tmp/claude-sl-*` with default umask (typically 0644), making them world-readable. Symlink attacks are also possible via predictable paths.

**Files:**
- Modify: `cache.sh:21-24`

- [ ] **Step 1: Replace `/tmp` cache path with per-user directory**

Replace lines 21-24 in `cache.sh`:

```sh
  # Cache file path
  _cr_hash=$(printf '%s' "$sl_cwd" | $SL_MD5_CMD 2>/dev/null)
  _cr_hash="${_cr_hash%% *}"
  _cr_cache="/tmp/claude-sl-${_cr_hash}"
```

With:

```sh
  # Cache directory: prefer $TMPDIR (per-user on macOS), fall back to /tmp with user ID
  _cr_cache_dir="${TMPDIR:-/tmp}/claude-statusline-$(id -u)"
  if [ ! -d "$_cr_cache_dir" ]; then
    mkdir -p "$_cr_cache_dir" 2>/dev/null
    chmod 700 "$_cr_cache_dir" 2>/dev/null
  fi
  _cr_hash=$(printf '%s' "$sl_cwd" | $SL_MD5_CMD 2>/dev/null)
  _cr_hash="${_cr_hash%% *}"
  _cr_cache="${_cr_cache_dir}/${_cr_hash}"
```

This uses `$TMPDIR` which on macOS is a per-user path like `/var/folders/xx/...`. On Linux, falls back to `/tmp/claude-statusline-<uid>` with `chmod 700`.

- [ ] **Step 2: Run `sh -n cache.sh` syntax check**

```sh
sh -n cache.sh
```

- [ ] **Step 3: Run test harness**

```sh
sh test.sh mid
```

Expected: renders correctly. Verify cache dir was created:

```sh
ls -ld "${TMPDIR:-/tmp}/claude-statusline-$(id -u)"
```

Expected: `drwx------` permissions.

- [ ] **Step 4: Update .gitignore -- remove misleading `/tmp/` entry**

The `.gitignore` has `/tmp/` which matches `./tmp/` in the repo root, not the system `/tmp` where cache files live. This is confusing. Remove it since cache files are never in the repo.

In `.gitignore`, remove line 17 (`/tmp/`). Replace the comment above it:

```
# Git cache temp files
/tmp/
```

With nothing (delete both lines). The section header and entry are both gone.

---

## Chunk 2: Important Code Quality Fixes

### Task 3: Fix stash count whitespace on macOS

macOS `wc -l` outputs leading spaces (e.g., `"       3"`). The current `${sl_stash_count## }` only strips one space. On the first invocation (no cache), `_seg_detail` in `git.sh` will show extra whitespace.

**Files:**
- Modify: `cache.sh:60-62`

- [ ] **Step 1: Replace string trimming with arithmetic normalization**

Replace lines 60-62 in `cache.sh`:

```sh
  # Stash
  sl_stash_count=$(git -C "$sl_cwd" stash list 2>/dev/null | wc -l)
  sl_stash_count="${sl_stash_count## }"
```

With:

```sh
  # Stash (arithmetic normalizes macOS wc -l leading spaces)
  sl_stash_count=$(git -C "$sl_cwd" stash list 2>/dev/null | wc -l)
  sl_stash_count=$(( sl_stash_count + 0 ))
```

- [ ] **Step 2: Verify syntax**

```sh
sh -n cache.sh
```

---

### Task 4: Fix model micro abbreviation for single-word names

When `sl_model_short` is a single word (e.g., fallback `"Claude"`), the `${var#* }` pattern returns the full string unchanged, producing `"Cl Claude"` in micro tier.

**Files:**
- Modify: `segments/model.sh:28-34`

- [ ] **Step 1: Add single-word guard to micro abbreviation**

Replace lines 28-34 in `segments/model.sh`:

```sh
  # Tier-aware content
  case "$_sl_tier" in
    micro)
      # Abbreviate: "Opus 4.6" -> "Op 4.6", "Sonnet 4.6" -> "So 4.6"
      _m_name="${sl_model_short%% *}"
      _m_ver="${sl_model_short#* }"
      _seg_content="$(printf '%.2s' "$_m_name") ${_m_ver}"
      ;;
    *)
      _seg_content="$sl_model_short"
      ;;
  esac
```

With:

```sh
  # Tier-aware content
  case "$_sl_tier" in
    micro)
      # Abbreviate: "Opus 4.6" -> "Op 4.6"; single words pass through
      case "$sl_model_short" in
        *" "*)
          _m_name="${sl_model_short%% *}"
          _m_ver="${sl_model_short#* }"
          _seg_content="$(printf '%.2s' "$_m_name") ${_m_ver}"
          ;;
        *)
          _seg_content="$sl_model_short"
          ;;
      esac
      ;;
    *)
      _seg_content="$sl_model_short"
      ;;
  esac
```

- [ ] **Step 2: Verify syntax**

```sh
sh -n segments/model.sh
```

- [ ] **Step 3: Run test harness micro tier to verify**

```sh
sh test.sh mid  # mid scenario has model name with space -- check micro tier
```

---

### Task 5: Move OSC 8 link wrapping to segment metadata

Segments embed raw OSC 8 escape sequences in `_seg_content`, violating the "no ANSI in segments" contract. Fix by adding `_seg_link_url` to the segment metadata. The orchestrator applies the link wrapping.

**Files:**
- Modify: `segments/project.sh:16`
- Modify: `segments/git.sh:25-30`
- Modify: `lib.sh:196-283` (in `render_row`)

- [ ] **Step 1: Add `_seg_link_url` to metadata reset in `render_row`**

In `lib.sh`, line 206, add `_seg_link_url=""` to the metadata reset block:

```sh
    _seg_weight="" ; _seg_min_tier="" ; _seg_group=""
    _seg_content="" ; _seg_icon="" ; _seg_bg="" ; _seg_fg=""
    _seg_attrs="" ; _seg_detail=""
```

Becomes:

```sh
    _seg_weight="" ; _seg_min_tier="" ; _seg_group=""
    _seg_content="" ; _seg_icon="" ; _seg_bg="" ; _seg_fg=""
    _seg_attrs="" ; _seg_detail="" ; _seg_link_url=""
```

- [ ] **Step 2: Apply OSC 8 wrapping in the orchestrator**

In `lib.sh`, after the icon handling block (after line 227) and before attribute handling (line 230), add link wrapping:

```sh
    # OSC 8 link wrapping (orchestrator applies, not segments)
    if [ "$SL_CAP_OSC8" -eq 1 ] && [ -n "$_seg_link_url" ]; then
      _seg_content=$(printf '\033]8;;%s\a%s\033]8;;\a' "$_seg_link_url" "$_seg_content")
    fi
```

- [ ] **Step 3: Update `project.sh` to use `_seg_link_url` instead of `osc8_link`**

Replace line 16 in `segments/project.sh`:

```sh
  _seg_content=$(osc8_link "$sl_github_base_url" "$sl_project")
```

With:

```sh
  _seg_content="$sl_project"
  _seg_link_url="$sl_github_base_url"
```

- [ ] **Step 4: Update `git.sh` to use `_seg_link_url` instead of `osc8_link`**

Replace lines 25-30 in `segments/git.sh`:

```sh
  # Branch name with OSC 8 link
  _gi_branch_url=""
  if [ -n "$sl_github_base_url" ] && [ "$sl_is_detached" -eq 0 ]; then
    _gi_branch_url="${sl_github_base_url}/tree/${sl_branch}"
  fi
  _gi_branch_text=$(osc8_link "$_gi_branch_url" "$sl_branch")
```

With:

```sh
  # Branch link URL for orchestrator to wrap via _seg_link_url
  if [ -n "$sl_github_base_url" ] && [ "$sl_is_detached" -eq 0 ]; then
    _seg_link_url="${sl_github_base_url}/tree/${sl_branch}"
  fi
```

And update lines 33-46 to use `$sl_branch` directly instead of `$_gi_branch_text`:

Replace:

```sh
  case "$_sl_tier" in
    compact)
      # Branch name only
      _seg_content="$_gi_branch_text"
      ;;
    full|*)
      # Full: branch + ahead/behind + stash
      # Detail suffix rendered in dim by orchestrator via _seg_detail
      _seg_detail=""
      [ "$sl_ahead" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail}^${sl_ahead}"
      [ "$sl_behind" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail}v${sl_behind}"
      [ "$sl_stash_count" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail} *${sl_stash_count}"

      _seg_content="$_gi_branch_text"
      ;;
  esac
```

With:

```sh
  _seg_content="$sl_branch"

  case "$_sl_tier" in
    full|*)
      # Detail suffix rendered in dim by orchestrator via _seg_detail
      _seg_detail=""
      [ "$sl_ahead" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail}^${sl_ahead}"
      [ "$sl_behind" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail}v${sl_behind}"
      [ "$sl_stash_count" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail} *${sl_stash_count}"
      ;;
  esac
```

- [ ] **Step 5: Verify syntax of all changed files**

```sh
sh -n lib.sh && sh -n segments/project.sh && sh -n segments/git.sh
```

- [ ] **Step 6: Run full test harness**

```sh
sh test.sh full && sh test.sh mid && sh test.sh minimal
```

Expected: renders correctly. OSC 8 links still functional in terminals that support them.

---

### Task 6: Clean up README for public release

Remove placeholder TODO and replace `YOUR_USER` with the actual GitHub username.

**Files:**
- Modify: `README.md:7-8, 31`

- [ ] **Step 1: Remove screenshot TODO placeholder**

Delete line 7-8 in `README.md`:

```
<!-- TODO: Add screenshot here -->
```

- [ ] **Step 2: Replace `YOUR_USER` with `gfreschi`**

Replace in `README.md` line 31:

```sh
git clone https://github.com/YOUR_USER/claude-statusline.git ~/.claude/statusline
```

With:

```sh
git clone https://github.com/gfreschi/claude-statusline.git ~/.claude/statusline
```

---

## Chunk 3: Suggestions and Polish

### Task 7: Fix Nord theme Sonnet/Haiku collision

Both `PALETTE_BLUE` and `PALETTE_CYAN` are set to `110` in `themes/nord.sh`, making Sonnet and Haiku visually identical. Use a distinct Nord Frost color for Haiku.

**Files:**
- Modify: `themes/nord.sh:26, 30`

- [ ] **Step 1: Change `PALETTE_CYAN` and add `C_HAIKU_BG` override**

In `themes/nord.sh`, change line 26:

```sh
PALETTE_CYAN=110
```

To:

```sh
PALETTE_CYAN=116
```

`116` is closer to Nord's `#88c0d0` Frost color and is visually distinct from `110`.

Also update the comment table on line 13 to match:

```
# Cyan              | Frost        | #88c0d0 | 110
```

To:

```
# Cyan              | Frost        | #88c0d0 | 116
```

- [ ] **Step 2: Verify syntax and visuals**

```sh
sh -n themes/nord.sh && sh test.sh mid nord
```

Expected: Sonnet (blue, 110) and Haiku (cyan, 116) have visibly different backgrounds.

---

### Task 8: Deduplicate context gauge dot-building

The dot-building loop in `segments/context.sh` is duplicated identically between compact (lines 49-54) and full (lines 72-77) tiers. Compute it once before the tier `case`.

**Files:**
- Modify: `segments/context.sh:40-116`

- [ ] **Step 1: Extract dot-building before the tier case**

Replace lines 40-116 in `segments/context.sh`:

```sh
  # --- Build content by tier ---
  case "$_sl_tier" in
    micro)
      # Just percentage
      _seg_content="${_cx_pct}%"
      _seg_icon=""
      ;;
    compact)
      # Dots + % + tokens (no compaction ETA)
      _cx_dots=""
      _cx_filled=$(( _cx_pct / 20 ))
      [ "$_cx_filled" -gt 5 ] && _cx_filled=5
      _cx_empty=$(( 5 - _cx_filled ))
      _cx_i=0; while [ "$_cx_i" -lt "$_cx_filled" ]; do _cx_dots="${_cx_dots}${GL_DOT_FILLED}"; _cx_i=$((_cx_i+1)); done
      _cx_i=0; while [ "$_cx_i" -lt "$_cx_empty" ];  do _cx_dots="${_cx_dots}${GL_DOT_EMPTY}";  _cx_i=$((_cx_i+1)); done

      _cx_tokens=""
      _cx_size_val=$(( sl_ctx_size + 0 )) 2>/dev/null || _cx_size_val=0
      if [ "$_cx_size_val" -gt 0 ]; then
        _cx_used_tok=$(( _cx_size_val * _cx_pct / 100 ))
        format_tokens _cx_used_fmt "$_cx_used_tok"
        format_tokens _cx_max_fmt "$_cx_size_val"
        _cx_tokens=" ${_cx_used_fmt}/${_cx_max_fmt}"
      fi

      _cx_prefix=""
      [ "$_cx_pct" -ge 95 ] && _cx_prefix="${GL_WARN} CTX! "

      _seg_content="${_cx_prefix}${_cx_dots} ${_cx_pct}%${_cx_tokens}"
      ;;
    full|*)
      # Dots + % + tokens + compaction ETA
      _cx_dots=""
      _cx_filled=$(( _cx_pct / 20 ))
      [ "$_cx_filled" -gt 5 ] && _cx_filled=5
      _cx_empty=$(( 5 - _cx_filled ))
      _cx_i=0; while [ "$_cx_i" -lt "$_cx_filled" ]; do _cx_dots="${_cx_dots}${GL_DOT_FILLED}"; _cx_i=$((_cx_i+1)); done
      _cx_i=0; while [ "$_cx_i" -lt "$_cx_empty" ];  do _cx_dots="${_cx_dots}${GL_DOT_EMPTY}";  _cx_i=$((_cx_i+1)); done

      _cx_tokens=""
      _cx_size_val=$(( sl_ctx_size + 0 )) 2>/dev/null || _cx_size_val=0
      if [ "$_cx_size_val" -gt 0 ]; then
        _cx_used_tok=$(( _cx_size_val * _cx_pct / 100 ))
        format_tokens _cx_used_fmt "$_cx_used_tok"
        format_tokens _cx_max_fmt "$_cx_size_val"
        _cx_tokens=" ${_cx_used_fmt}/${_cx_max_fmt}"
      fi

      # Compaction countdown
      _cx_compact=""
      _cx_compact_pct="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-95}"
      _cx_dur_val=$(( sl_duration_ms + 0 )) 2>/dev/null || _cx_dur_val=0

      if [ "$_cx_dur_val" -ge 60000 ] && [ "$_cx_pct" -ge 50 ] && [ "$_cx_pct" -lt 95 ] && [ "$_cx_size_val" -gt 0 ]; then
        _cx_current=$(( _cx_size_val * _cx_pct / 100 ))
        _cx_target=$(( _cx_size_val * _cx_compact_pct / 100 ))
        _cx_remaining=$(( _cx_target - _cx_current ))
        if [ "$_cx_remaining" -gt 0 ] && [ "$_cx_current" -gt 0 ]; then
          _cx_ms_to_compact=$(( _cx_remaining * _cx_dur_val / _cx_current ))
          _cx_min_to_compact=$(( _cx_ms_to_compact / 60000 ))
          if [ "$_cx_min_to_compact" -gt 480 ]; then
            _cx_compact=" compact >8h"
          elif [ "$_cx_min_to_compact" -ge 60 ]; then
            _cx_hrs=$(( _cx_min_to_compact / 60 ))
            _cx_compact=" compact ~${_cx_hrs}h"
          elif [ "$_cx_min_to_compact" -gt 0 ]; then
            _cx_compact=" compact ~${_cx_min_to_compact}min"
          fi
        fi
      fi

      _cx_prefix=""
      [ "$_cx_pct" -ge 95 ] && _cx_prefix="${GL_WARN} CTX! "

      _seg_content="${_cx_prefix}${_cx_dots} ${_cx_pct}%${_cx_tokens}${_cx_compact}"
      ;;
  esac
```

With:

```sh
  # --- Shared: dots, tokens, prefix (used by compact + full) ---
  _cx_dots=""
  _cx_tokens=""
  _cx_prefix=""
  _cx_size_val=$(( sl_ctx_size + 0 )) 2>/dev/null || _cx_size_val=0

  if [ "$_sl_tier" != "micro" ]; then
    _cx_filled=$(( _cx_pct / 20 ))
    [ "$_cx_filled" -gt 5 ] && _cx_filled=5
    _cx_empty=$(( 5 - _cx_filled ))
    _cx_i=0; while [ "$_cx_i" -lt "$_cx_filled" ]; do _cx_dots="${_cx_dots}${GL_DOT_FILLED}"; _cx_i=$((_cx_i+1)); done
    _cx_i=0; while [ "$_cx_i" -lt "$_cx_empty" ];  do _cx_dots="${_cx_dots}${GL_DOT_EMPTY}";  _cx_i=$((_cx_i+1)); done

    if [ "$_cx_size_val" -gt 0 ]; then
      _cx_used_tok=$(( _cx_size_val * _cx_pct / 100 ))
      format_tokens _cx_used_fmt "$_cx_used_tok"
      format_tokens _cx_max_fmt "$_cx_size_val"
      _cx_tokens=" ${_cx_used_fmt}/${_cx_max_fmt}"
    fi

    [ "$_cx_pct" -ge 95 ] && _cx_prefix="${GL_WARN} CTX! "
  fi

  # --- Build content by tier ---
  case "$_sl_tier" in
    micro)
      _seg_content="${_cx_pct}%"
      _seg_icon=""
      ;;
    compact)
      _seg_content="${_cx_prefix}${_cx_dots} ${_cx_pct}%${_cx_tokens}"
      ;;
    full|*)
      # Compaction countdown (full tier only)
      _cx_compact=""
      _cx_compact_pct="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-95}"
      _cx_dur_val=$(( sl_duration_ms + 0 )) 2>/dev/null || _cx_dur_val=0

      if [ "$_cx_dur_val" -ge 60000 ] && [ "$_cx_pct" -ge 50 ] && [ "$_cx_pct" -lt 95 ] && [ "$_cx_size_val" -gt 0 ]; then
        _cx_current=$(( _cx_size_val * _cx_pct / 100 ))
        _cx_target=$(( _cx_size_val * _cx_compact_pct / 100 ))
        _cx_remaining=$(( _cx_target - _cx_current ))
        if [ "$_cx_remaining" -gt 0 ] && [ "$_cx_current" -gt 0 ]; then
          _cx_ms_to_compact=$(( _cx_remaining * _cx_dur_val / _cx_current ))
          _cx_min_to_compact=$(( _cx_ms_to_compact / 60000 ))
          if [ "$_cx_min_to_compact" -gt 480 ]; then
            _cx_compact=" compact >8h"
          elif [ "$_cx_min_to_compact" -ge 60 ]; then
            _cx_hrs=$(( _cx_min_to_compact / 60 ))
            _cx_compact=" compact ~${_cx_hrs}h"
          elif [ "$_cx_min_to_compact" -gt 0 ]; then
            _cx_compact=" compact ~${_cx_min_to_compact}min"
          fi
        fi
      fi

      _seg_content="${_cx_prefix}${_cx_dots} ${_cx_pct}%${_cx_tokens}${_cx_compact}"
      ;;
  esac
```

- [ ] **Step 2: Verify syntax**

```sh
sh -n segments/context.sh
```

- [ ] **Step 3: Run test harness across all scenarios**

```sh
for s in minimal mid full critical; do sh test.sh "$s"; done
```

---

### Task 9: Remove redundant `SL_CAP_UNICODE=1` assignment

In `lib.sh` line 12, `SL_CAP_UNICODE=1` is set immediately before the `case` that overwrites it.

**Files:**
- Modify: `lib.sh:12`

- [ ] **Step 1: Remove the redundant assignment**

Replace lines 11-16 in `lib.sh`:

```sh
  # Unicode: check locale
  SL_CAP_UNICODE=1
  case "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" in
    *[Uu][Tt][Ff]*) SL_CAP_UNICODE=1 ;;
    *)              SL_CAP_UNICODE=0 ;;
  esac
```

With:

```sh
  # Unicode: check locale
  case "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" in
    *[Uu][Tt][Ff]*) SL_CAP_UNICODE=1 ;;
    *)              SL_CAP_UNICODE=0 ;;
  esac
```

- [ ] **Step 2: Verify syntax**

```sh
sh -n lib.sh
```

---

### Task 10: Document `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env var

The variable is used in `segments/context.sh` but not documented in the README.

**Files:**
- Modify: `README.md` (Configuration table)

- [ ] **Step 1: Add env var to the Configuration table**

In `README.md`, add a row to the Configuration table (after the `CLAUDE_STATUSLINE_NERD_FONT` row):

```
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` | Context percentage at which compaction countdown targets |
```

---

### Task 11: Document intentional `set -e` omission in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (Design Decisions section)

- [ ] **Step 1: Add note about `set -e`**

Add to the "Design Decisions" section in `CLAUDE.md`:

```
- **No `set -e`:** Intentionally omitted. A status line should degrade gracefully to partial output on errors rather than producing no output at all. Individual failures (e.g., missing git, broken JSON) result in skipped segments, not a blank line.
```

---

## Chunk 4: Open-Source Project Files

### Task 12: Add CONTRIBUTING.md

Standard open-source contributor guide.

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Create CONTRIBUTING.md**

```md
# Contributing

Contributions are welcome. Please open an issue to discuss larger changes before submitting a PR.

## Requirements

- POSIX `sh` only -- no bashisms (`[[ ]]`, arrays, `local`, process substitution)
- `jq` for JSON parsing
- A 256-color terminal for visual testing

## Development

Run the test harness after any change:

    sh test.sh full

Test all scenarios and themes:

    for s in minimal mid full critical; do sh test.sh "$s"; done
    for t in catppuccin-mocha bluloco-dark dracula nord; do sh test.sh mid "$t"; done

Syntax-check all files:

    find . -name '*.sh' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}

## Adding a Segment

1. Create `segments/my-segment.sh` with a `segment_my_segment()` function
2. Set all `_seg_*` metadata variables, return 0 to render or 1 to skip
3. Add `segment_my_segment` to `SL_SEGMENTS` in `main.sh`
4. Run syntax check and test harness

See `CLAUDE.md` for the full segment contract and variable naming conventions.

## Adding a Theme

1. Create `themes/my-theme.sh` with all 12 `PALETTE_*` variables
2. Optionally override specific `C_*` tokens
3. Run syntax check: `sh -n themes/my-theme.sh`
4. Test: `sh test.sh full my-theme`

## Style

- Prefix function-local variables with `_xx_` (2-3 letter function abbreviation)
- Segments must NOT embed raw ANSI escapes in `_seg_content`
- Use `${VAR:-default}` pattern for overridable values
- Use `$(( ))` for arithmetic
```

---

### Task 13: Add .editorconfig

Ensures consistent formatting across editors for contributors.

**Files:**
- Create: `.editorconfig`

- [ ] **Step 1: Create .editorconfig**

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
```

---

## Chunk 5: Update CLAUDE.md Documentation

### Task 14: Update CLAUDE.md with new `_seg_link_url` metadata

Reflect the new segment metadata variable added in Task 5.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add `_seg_link_url` to the segment metadata table**

In the "Metadata variables set by segments" table in `CLAUDE.md`, add a row:

```
| `_seg_link_url` | URL or empty | OSC 8 hyperlink target; orchestrator wraps `_seg_content` if set |
```

- [ ] **Step 2: Update segment contract note**

In the same section, update:

```
**Segments must NOT embed raw ANSI escapes in `_seg_content`.**
```

To:

```
**Segments must NOT embed raw ANSI escapes in `_seg_content`.** Use `_seg_link_url` for OSC 8 hyperlinks -- the orchestrator wraps the content.
```

---

## Final Verification

After all tasks complete:

- [ ] Run syntax check on all files:

```sh
find . -name '*.sh' -print0 | xargs -0 -I{} sh -c 'sh -n "$1" || echo "FAIL: $1"' _ {}
```

- [ ] Run all scenarios across all themes:

```sh
for t in catppuccin-mocha bluloco-dark dracula nord; do
  for s in minimal mid full critical; do
    sh test.sh "$s" "$t"
  done
done
```

- [ ] Verify no bashisms slipped in (quick grep):

```sh
grep -rn '\[\[' --include='*.sh' .
grep -rn 'local ' --include='*.sh' .
grep -rn 'declare ' --include='*.sh' .
```
