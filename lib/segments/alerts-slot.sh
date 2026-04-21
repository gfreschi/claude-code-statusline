#!/bin/sh
# segments/alerts-slot.sh -- Priority-rotating alerts segment (Row 1 / session)
# Priority: cache-poor (<70%) > added-dirs > 7d-warning (zen only, >=70%)

segment_alerts_slot() {
  _as_hit=0

  # 1. Cache-poor
  to_int _as_read "$sl_cache_read_tokens" 0
  if [ "$_as_read" -gt 0 ]; then
    to_int _as_create "$sl_cache_create_tokens" 0
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
    to_int _as_dirs "$sl_added_dirs_count" 0
    if [ "$_as_dirs" -gt 0 ]; then
      _seg_icon=""
      _seg_content="+${_as_dirs} dirs"
      _seg_fg=$C_DIM
      _as_hit=1
    fi
  fi

  # 3. 7d warning: fires in both layouts. In classic this is the only
  # 7d signal when >=70% (rate_limit_7d_stable self-gates below 70%),
  # so gating the alert to zen would leave classic blind to crit 7d.
  if [ "$_as_hit" -eq 0 ]; then
    to_int _as_7d "$sl_rate_7d_pct" -1
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

  # Minimalist override: collapse word labels to 1-char unit prefixes so the
  # value keeps its type (d=dirs, c=cache, w=weekly) instead of becoming a
  # bare integer. Use BRE [0-9][0-9]* to match multi-digit counts.
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_content=$(printf '%s' "$_seg_content" | sed 's/^cache /c/;s/^+\([0-9][0-9]*\) dirs/d\1/;s/^7d /w/')
  fi

  return 0
}
