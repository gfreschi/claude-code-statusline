#!/bin/sh
# segments/rate-limit-7d-stable.sh -- 7d rate-limit stable pill (zen Row 3 only)
# Self-gates on $_sl_layout and 7d threshold. Returns non-zero outside zen
# or when 7d >= 70% (that case is handled by segment_alerts_slot).

segment_rate_limit_7d_stable() {
  [ "$_sl_layout" != "zen" ] && return 1

  [ -z "$sl_rate_7d_pct" ] && return 1
  to_int _r7_pct "$sl_rate_7d_pct" -1
  [ "$_r7_pct" -lt 0 ] && return 1
  [ "$_r7_pct" -ge 70 ] && return 1

  # Days remaining. $_sl_now is memoized once in main.sh.
  _r7_now=$_sl_now
  to_int _r7_reset "$sl_rate_7d_reset_ts" 0
  _r7_secs=$(( _r7_reset - _r7_now ))
  [ "$_r7_secs" -lt 0 ] && _r7_secs=0
  _r7_days=$(( _r7_secs / 86400 ))

  # Sanity clamp: 7d window is 604800s; past 8d of remaining time the
  # upstream sent a garbage resets_at. Show "?" instead of "95180d".
  if [ "$_r7_secs" -gt 691200 ]; then
    _r7_days="?"
  fi

  _seg_weight="recessed"
  _seg_min_tier="zen"
  _seg_group="ambient"
  _seg_group_fallback=""   # does not render in classic
  _seg_icon=""
  _seg_attrs=""
  _seg_content="7d ${_r7_pct}% ${GL_SEP} ${_r7_days}d"

  # Minimalist override: drop word label
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_content="${_r7_pct}% ${_r7_days}d"
  fi

  return 0
}
