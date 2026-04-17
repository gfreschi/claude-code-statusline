#!/bin/sh
# segments/duration.sh -- Session duration (tier-aware weight)
# Reads: sl_duration_ms, sl_api_duration_ms, _sl_tier

segment_duration() {
  _du_ms=$(( sl_duration_ms + 0 )) 2>/dev/null || _du_ms=0
  _du_sec=$(( _du_ms / 1000 ))

  [ "$_du_sec" -lt 60 ] && return 1

  _seg_min_tier="compact"
  _seg_group="workspace"
  _seg_icon="$GL_CLOCK"
  _seg_attrs=""
  _seg_bg="" ; _seg_fg="" ; _seg_detail=""

  # Weight changes by tier
  case "$_sl_tier" in
    full)    _seg_weight="recessed" ;;
    *)       _seg_weight="tertiary" ;;
  esac

  # Format time
  if [ "$_du_sec" -ge 3600 ]; then
    _du_h=$(( _du_sec / 3600 ))
    _du_m=$(( (_du_sec % 3600) / 60 ))
    _seg_content=$(printf '%dh%02dm' "$_du_h" "$_du_m")
  else
    _du_m=$(( _du_sec / 60 ))
    _seg_content="${_du_m}m"
  fi

  # Color escalation (FG)
  if [ "$_du_sec" -ge 7200 ]; then
    _seg_fg=$C_DUR_CRIT
  elif [ "$_du_sec" -ge 3600 ]; then
    _seg_fg=$C_DUR_HIGH
  elif [ "$_du_sec" -ge 1800 ]; then
    _seg_fg=$C_DUR_MED
  else
    _seg_fg=$C_DUR_LOW
  fi

  # API-time suffix (full/zen only): report how much wall time was spent in
  # API calls so users can spot sessions dominated by waiting/thinking.
  # Guard empty-string arithmetic: api_duration_ms may be empty.
  if [ "$_sl_tier" = "full" ] || [ "$_sl_tier" = "zen" ]; then
    case "$sl_api_duration_ms" in
      ''|*[!0-9]*) _du_api_ms=0 ;;
      *) _du_api_ms=$sl_api_duration_ms ;;
    esac
    if [ "$_du_api_ms" -ge 60000 ] && [ "$_du_api_ms" -lt "$_du_ms" ]; then
      _du_api_min=$(( _du_api_ms / 60000 ))
      _seg_detail="(api ${_du_api_min}m)"

      # Escalation: after 20 min wall time, if <15% was API, dim warning.
      _du_wall_min=$(( _du_sec / 60 ))
      if [ "$_du_wall_min" -ge 20 ]; then
        _du_api_pct=$(( _du_api_ms * 100 / (_du_ms + 1) ))
        if [ "$_du_api_pct" -lt 15 ]; then
          _seg_fg=$C_DUR_MED
        fi
      fi
    fi
  fi

  # Minimalist override: drop API-time suffix
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_detail=""
  fi

  return 0
}
