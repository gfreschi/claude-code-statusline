#!/bin/sh
# cache.sh -- Git cache with 5s TTL
# Requires: SL_MD5_CMD, SL_STAT_FMT from lib.sh detect_platform()
# Reads: sl_cwd
# Sets: sl_branch, sl_is_detached, sl_is_dirty, sl_ahead, sl_behind,
#       sl_stash_count, sl_remote_url, sl_github_base_url

SL_CACHE_TTL=5

# --- cache_refresh() ---
# Checks cache freshness, runs git commands if stale
cache_refresh() {
  # Defaults
  sl_branch="" ; sl_is_detached=0 ; sl_is_dirty=0
  sl_ahead=0 ; sl_behind=0 ; sl_stash_count=0
  sl_remote_url="" ; sl_github_base_url=""

  [ -z "$sl_cwd" ] && return
  git -C "$sl_cwd" rev-parse --git-dir >/dev/null 2>&1 || return

  # Cache directory: prefer $TMPDIR (per-user on macOS), fall back to /tmp with user ID
  _cr_cache_dir="${TMPDIR:-/tmp}/claude-code-statusline-$(id -u)"
  if [ ! -d "$_cr_cache_dir" ]; then
    mkdir -p "$_cr_cache_dir" 2>/dev/null
    chmod 700 "$_cr_cache_dir" 2>/dev/null
  fi
  _cr_hash=$(printf '%s' "$sl_cwd" | $SL_MD5_CMD 2>/dev/null)
  _cr_hash="${_cr_hash%% *}"
  _cr_cache="${_cr_cache_dir}/${_cr_hash}"

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
