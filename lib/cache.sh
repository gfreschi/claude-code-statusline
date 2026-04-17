#!/bin/sh
# cache.sh -- Git cache with 5s TTL
# Requires: SL_MD5_CMD, SL_STAT_FMT from lib.sh detect_platform()
# Reads: sl_cwd
# Sets: sl_branch, sl_is_detached, sl_is_dirty, sl_ahead, sl_behind,
#       sl_stash_count, sl_remote_url, sl_github_base_url

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

  # Dirty check
  if ! git -C "$sl_cwd" diff-index --quiet HEAD -- 2>/dev/null; then
    sl_is_dirty=1
  elif [ -n "$(git -C "$sl_cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
    sl_is_dirty=1
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
}

# --- Sparkline ring buffer (8 samples) ---
# File: $SL_CACHE_DIR/burn-history
# Format: single line, 8 comma-separated non-negative integers, oldest first.
# Reader/writer sanitize values via printf '%d' to prevent injection.

sparkline_push() {
  # args: value (integer, tokens/minute)
  # Appends to ring buffer, keeps newest 8. Sanitizes every value to non-negative int.
  _sp_val=${1:-0}
  case "$_sp_val" in
    ''|*[!0-9-]*|-*[!0-9]*) _sp_val=0 ;;
    *) _sp_val=$(printf '%d' "$_sp_val" 2>/dev/null); [ -z "$_sp_val" ] && _sp_val=0 ;;
  esac
  [ "$_sp_val" -lt 0 ] 2>/dev/null && _sp_val=0
  _sp_file="$SL_CACHE_DIR/burn-history"
  mkdir -p "$SL_CACHE_DIR" 2>/dev/null
  chmod 0700 "$SL_CACHE_DIR" 2>/dev/null

  # Read existing buffer, sanitize every token to guard against corruption
  _sp_sanitized=""
  if [ -r "$_sp_file" ]; then
    _sp_raw=$(cat "$_sp_file" 2>/dev/null)
    _sp_oifs=$IFS
    IFS=','
    for _sp_tok in $_sp_raw; do
      # Strip any embedded newlines / whitespace, coerce via printf '%d'
      _sp_tok=$(printf '%s' "$_sp_tok" | tr -d '\r\n\t ')
      [ -z "$_sp_tok" ] && continue
      case "$_sp_tok" in
        ''|*[!0-9-]*|-*[!0-9]*) _sp_clean=0 ;;
        *) _sp_clean=$(printf '%d' "$_sp_tok" 2>/dev/null); [ -z "$_sp_clean" ] && _sp_clean=0 ;;
      esac
      [ "$_sp_clean" -lt 0 ] 2>/dev/null && _sp_clean=0
      if [ -z "$_sp_sanitized" ]; then
        _sp_sanitized="$_sp_clean"
      else
        _sp_sanitized="${_sp_sanitized},${_sp_clean}"
      fi
    done
    IFS=$_sp_oifs
  fi

  # Append new value
  if [ -z "$_sp_sanitized" ]; then
    _sp_new="$_sp_val"
  else
    _sp_new="${_sp_sanitized},${_sp_val}"
  fi

  # Keep last 8 (relies on printf '%s\n' producing a trailing newline so wc -l
  # counts commas + 1; do not drop the \n)
  _sp_count=$(printf '%s\n' "$_sp_new" | tr ',' '\n' | wc -l | tr -d ' ')
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
