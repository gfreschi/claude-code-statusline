#!/bin/sh
# segments/duration.sh -- Session duration (tier-aware weight)
# Reads: sl_duration_ms, _sl_tier

segment_duration() {
  _du_ms=$(( sl_duration_ms + 0 )) 2>/dev/null || _du_ms=0
  _du_sec=$(( _du_ms / 1000 ))

  [ "$_du_sec" -lt 60 ] && return 1

  _seg_min_tier="compact"
  _seg_group="workspace"
  _seg_icon="$GL_CLOCK"
  _seg_attrs=""
  _seg_bg="" ; _seg_fg=""

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

  return 0
}
