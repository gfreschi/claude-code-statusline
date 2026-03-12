#!/bin/sh
# segments/cache-stats.sh -- Cache hit ratio (conditional)
# Reads: sl_cache_read_tokens, sl_cache_create_tokens

segment_cache_stats() {
  _cs_read=$(( sl_cache_read_tokens + 0 )) 2>/dev/null || _cs_read=0
  [ "$_cs_read" -le 0 ] && return 1

  _cs_create=$(( sl_cache_create_tokens + 0 )) 2>/dev/null || _cs_create=0
  _cs_total=$(( _cs_read + _cs_create ))
  [ "$_cs_total" -le 0 ] && return 1

  _cs_pct=$(( _cs_read * 100 / _cs_total ))

  _seg_weight="tertiary"
  _seg_min_tier="full"
  _seg_group="session"
  _seg_icon="$GL_CACHE"
  _seg_attrs=""
  _seg_bg=""

  # Custom FG: good = default dim, poor = orange warning
  if [ "$_cs_pct" -lt 50 ]; then
    _seg_fg=$C_CACHE_POOR
  else
    _seg_fg=""  # orchestrator defaults to C_DIM
  fi

  _seg_content="cache:${_cs_pct}%"

  return 0
}
