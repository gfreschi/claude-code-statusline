#!/bin/sh
# cache.sh -- Git cache with 5s TTL
# Requires: SL_MD5_CMD, SL_STAT_FMT from render.sh detect_platform()
# Reads: sl_cwd
# Sets: sl_branch, sl_is_detached, sl_is_dirty, sl_ahead, sl_behind,
#       sl_stash_count, sl_remote_url, sl_github_base_url,
#       sl_git_staged, sl_git_unstaged, sl_git_untracked,
#       sl_git_op, sl_git_step, sl_git_fork

SL_CACHE_TTL=5

# Shared cache directory: prefer $TMPDIR (per-user on macOS), fall back to /tmp with user ID.
# Caller may override via SL_CACHE_DIR (useful for tests / isolation).
SL_CACHE_DIR="${SL_CACHE_DIR:-${TMPDIR:-/tmp}/claude-code-statusline-$(id -u)}"

# --- cache_refresh() ---
# Checks cache freshness, runs git commands if stale
cache_refresh() {
  # Defaults
  sl_branch="" ; sl_is_detached=0 ; sl_is_dirty=0
  sl_ahead=0 ; sl_behind=0 ; sl_stash_count=0
  sl_remote_url="" ; sl_github_base_url=""
  sl_git_staged=0 ; sl_git_unstaged=0 ; sl_git_untracked=0
  sl_git_op="" ; sl_git_step=""
  sl_git_fork=0

  [ -z "$sl_cwd" ] && return
  git -C "$sl_cwd" rev-parse --git-dir >/dev/null 2>&1 || return

  mkdir -p "$SL_CACHE_DIR" 2>/dev/null && chmod 700 "$SL_CACHE_DIR" 2>/dev/null
  _cr_hash=$(printf '%s' "$sl_cwd" | $SL_MD5_CMD 2>/dev/null)
  _cr_hash="${_cr_hash%% *}"
  _cr_cache="${SL_CACHE_DIR}/${_cr_hash}"

  # Check freshness
  if [ -f "$_cr_cache" ]; then
    _cr_mtime=$($SL_STAT_FMT "$_cr_cache" 2>/dev/null) || _cr_mtime=0
    _cr_now=$(date +%s)
    _cr_age=$(( _cr_now - _cr_mtime ))
    if [ "$_cr_age" -lt "$SL_CACHE_TTL" ]; then
      . "$_cr_cache"
      return
    fi
  fi

  # Stale or missing: run git commands
  sl_branch=$(git -C "$sl_cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$sl_branch" ]; then
    sl_branch=$(git -C "$sl_cwd" rev-parse --short HEAD 2>/dev/null)
    sl_is_detached=1
  fi

  # Porcelain status: derives dirty flag + staged/unstaged/untracked counts in a single git call
  _cr_porcelain=$(git -C "$sl_cwd" status --porcelain 2>/dev/null)
  if [ -n "$_cr_porcelain" ]; then
    sl_is_dirty=1
    sl_git_staged=$(printf '%s\n' "$_cr_porcelain" | awk '/^[MADRC]/ {n++} END {print n+0}')
    sl_git_unstaged=$(printf '%s\n' "$_cr_porcelain" | awk '/^.[MADRC]/ {n++} END {print n+0}')
    sl_git_untracked=$(printf '%s\n' "$_cr_porcelain" | awk '/^\?\?/ {n++} END {print n+0}')
  fi

  # Ahead/behind
  if [ "$sl_is_detached" -eq 0 ]; then
    _cr_ab=$(git -C "$sl_cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    if [ -n "$_cr_ab" ]; then
      sl_ahead="${_cr_ab%%	*}"
      sl_behind="${_cr_ab##*	}"
    fi
  fi

  # Stash (arithmetic normalizes macOS wc -l leading spaces)
  sl_stash_count=$(git -C "$sl_cwd" stash list 2>/dev/null | wc -l)
  sl_stash_count=$(( sl_stash_count + 0 ))

  # Mid-merge / mid-rebase detection (resolve real git-dir to support worktrees and subdirs)
  _cr_gitdir=$(git -C "$sl_cwd" rev-parse --git-dir 2>/dev/null)
  if [ -n "$_cr_gitdir" ]; then
    case "$_cr_gitdir" in
      /*) ;;
      *)  _cr_gitdir="$sl_cwd/$_cr_gitdir" ;;
    esac
    if [ -d "$_cr_gitdir/rebase-merge" ]; then
      sl_git_op="REBASING"
      if [ -r "$_cr_gitdir/rebase-merge/msgnum" ] && [ -r "$_cr_gitdir/rebase-merge/end" ]; then
        _cr_step=$(cat "$_cr_gitdir/rebase-merge/msgnum" 2>/dev/null | tr -d ' \t\r\n')
        _cr_total=$(cat "$_cr_gitdir/rebase-merge/end" 2>/dev/null | tr -d ' \t\r\n')
        [ -n "$_cr_step" ] && [ -n "$_cr_total" ] && sl_git_step="${_cr_step}/${_cr_total}"
      fi
    elif [ -d "$_cr_gitdir/rebase-apply" ]; then
      sl_git_op="REBASING"
      if [ -r "$_cr_gitdir/rebase-apply/next" ] && [ -r "$_cr_gitdir/rebase-apply/last" ]; then
        _cr_step=$(cat "$_cr_gitdir/rebase-apply/next" 2>/dev/null | tr -d ' \t\r\n')
        _cr_total=$(cat "$_cr_gitdir/rebase-apply/last" 2>/dev/null | tr -d ' \t\r\n')
        [ -n "$_cr_step" ] && [ -n "$_cr_total" ] && sl_git_step="${_cr_step}/${_cr_total}"
      fi
    elif [ -f "$_cr_gitdir/MERGE_HEAD" ]; then
      sl_git_op="MERGING"
    elif [ -f "$_cr_gitdir/CHERRY_PICK_HEAD" ]; then
      sl_git_op="CHERRY-PICKING"
    fi
  fi

  # Fork detection: origin vs upstream remote URLs differ -> fork
  _cr_origin=$(git -C "$sl_cwd" config --get remote.origin.url 2>/dev/null)
  _cr_upstream=$(git -C "$sl_cwd" config --get remote.upstream.url 2>/dev/null)
  if [ -n "$_cr_origin" ] && [ -n "$_cr_upstream" ] && [ "$_cr_origin" != "$_cr_upstream" ]; then
    sl_git_fork=1
  fi

  # Remote URL -> GitHub base URL
  sl_remote_url=$(git -C "$sl_cwd" remote get-url origin 2>/dev/null)
  sl_github_base_url=""
  if [ -n "$sl_remote_url" ]; then
    case "$sl_remote_url" in
      git@*:*)
        # SSH: git@github.com:user/repo.git -> https://github.com/user/repo
        _cr_host="${sl_remote_url#git@}"
        _cr_host="${_cr_host%%:*}"
        _cr_path="${sl_remote_url#*:}"
        _cr_path="${_cr_path%.git}"
        sl_github_base_url="https://${_cr_host}/${_cr_path}"
        ;;
      https://*.git|http://*.git)
        sl_github_base_url="${sl_remote_url%.git}"
        ;;
      https://*|http://*)
        sl_github_base_url="$sl_remote_url"
        ;;
    esac
  fi

  # Write cache atomically
  # String values: strip C0 + DEL first (git refs should never contain them,
  # but the cache is sourced -- treat git output as untrusted), then
  # single-quote-escape to prevent shell injection. Runs once per 5s TTL
  # so the cost is negligible.
  # Numeric values: %d already sanitizes to digits only
  _cr_tmp="${_cr_cache}.$$"
  sl_branch=$(printf '%s' "$sl_branch" | tr -d '\000-\037\177')
  sl_github_base_url=$(printf '%s' "$sl_github_base_url" | tr -d '\000-\037\177')
  sl_git_op=$(printf '%s' "$sl_git_op" | tr -d '\000-\037\177')
  sl_git_step=$(printf '%s' "$sl_git_step" | tr -d '\000-\037\177')
  _cr_sq_branch=$(printf '%s' "$sl_branch" | sed "s/'/'\\\\''/g")
  _cr_sq_url=$(printf '%s' "$sl_github_base_url" | sed "s/'/'\\\\''/g")
  _cr_sq_op=$(printf '%s' "$sl_git_op" | sed "s/'/'\\\\''/g")
  _cr_sq_step=$(printf '%s' "$sl_git_step" | sed "s/'/'\\\\''/g")
  {
    printf "sl_branch='%s'\n" "$_cr_sq_branch"
    printf 'sl_is_detached=%d\n' "$sl_is_detached"
    printf 'sl_is_dirty=%d\n' "$sl_is_dirty"
    printf 'sl_ahead=%d\n' "$sl_ahead"
    printf 'sl_behind=%d\n' "$sl_behind"
    printf 'sl_stash_count=%d\n' "$sl_stash_count"
    printf 'sl_git_staged=%d\n' "$sl_git_staged"
    printf 'sl_git_unstaged=%d\n' "$sl_git_unstaged"
    printf 'sl_git_untracked=%d\n' "$sl_git_untracked"
    printf "sl_github_base_url='%s'\n" "$_cr_sq_url"
    printf "sl_git_op='%s'\n" "$_cr_sq_op"
    printf "sl_git_step='%s'\n" "$_cr_sq_step"
    printf 'sl_git_fork=%d\n' "$sl_git_fork"
  } > "$_cr_tmp"
  mv "$_cr_tmp" "$_cr_cache"
  # Lock down to owner-only: the cache is sourced back as shell code, so
  # another user on a shared host must not be able to write to it.
  chmod 0600 "$_cr_cache" 2>/dev/null
}

# --- Sparkline ring buffer (8 samples) ---
# File: $SL_CACHE_DIR/burn-history
# Format: single line, 8 comma-separated non-negative integers, oldest first.
# Reader/writer sanitize values via printf '%d' to prevent injection.

sparkline_push() {
  # args: value (integer, tokens/minute)
  # Appends to ring buffer, keeps newest 8. All sanitization is done via
  # POSIX parameter expansion + case patterns -- no per-token subshells,
  # which kept the old implementation forking ~12 times per render. The
  # ring file is a controlled format (no embedded whitespace), so we
  # accept tokens verbatim once they pass the numeric-only case match and
  # fall back to 0 for anything suspect.
  _sp_val=${1:-0}
  case "$_sp_val" in
    ''|*[!0-9-]*|-*[!0-9]*|-*) _sp_val=0 ;;
  esac
  _sp_file="$SL_CACHE_DIR/burn-history"
  mkdir -p "$SL_CACHE_DIR" 2>/dev/null
  chmod 0700 "$SL_CACHE_DIR" 2>/dev/null

  # Read existing buffer via builtin `read` (the file is single-line by
  # construction). Avoids a $() subshell + cat fork.
  _sp_raw=""
  if [ -r "$_sp_file" ]; then
    IFS= read -r _sp_raw < "$_sp_file" 2>/dev/null || _sp_raw=""
  fi

  # Sanitize each token and rebuild the comma-joined buffer. Invalid
  # tokens coerce to 0 to preserve sample count (matches prior behaviour).
  _sp_sanitized=""
  _sp_oifs=$IFS
  IFS=','
  for _sp_tok in $_sp_raw; do
    case "$_sp_tok" in
      ''|*[!0-9-]*|-*[!0-9]*|-*) _sp_clean=0 ;;
      *) _sp_clean="$_sp_tok" ;;
    esac
    if [ -z "$_sp_sanitized" ]; then
      _sp_sanitized="$_sp_clean"
    else
      _sp_sanitized="${_sp_sanitized},${_sp_clean}"
    fi
  done
  IFS=$_sp_oifs

  # Append new value
  if [ -z "$_sp_sanitized" ]; then
    _sp_new="$_sp_val"
  else
    _sp_new="${_sp_sanitized},${_sp_val}"
  fi

  # Count tokens by walking comma boundaries in-shell (no printf|tr|wc pipe).
  _sp_count=1
  _sp_walk="$_sp_new"
  while [ "$_sp_walk" != "${_sp_walk#*,}" ]; do
    _sp_walk="${_sp_walk#*,}"
    _sp_count=$((_sp_count + 1))
  done
  while [ "$_sp_count" -gt 8 ]; do
    _sp_new="${_sp_new#*,}"
    _sp_count=$(( _sp_count - 1 ))
  done

  # Atomic write: tmp + mv, matching cache_refresh's pattern
  _sp_tmp="$_sp_file.$$"
  printf '%s\n' "$_sp_new" > "$_sp_tmp"
  mv "$_sp_tmp" "$_sp_file"
  chmod 0600 "$_sp_file" 2>/dev/null
}

sparkline_read() {
  # Prints the current ring as comma-separated, or empty string if missing.
  _sp_file="$SL_CACHE_DIR/burn-history"
  [ -r "$_sp_file" ] && cat "$_sp_file" 2>/dev/null
}
