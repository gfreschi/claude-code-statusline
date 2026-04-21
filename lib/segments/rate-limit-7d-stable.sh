#!/bin/sh
# segments/rate-limit-7d-stable.sh -- 7d rate-limit stable pill
#
# Zen: renders on Row 3 (ambient, recessed) as the slow-moving quota signal.
# Classic: renders on Row 1 (session, tertiary) so classic users do not lose
# 7d visibility just because they are not in zen layout.
# Both: self-gates when >= 70% (alerts_slot handles the warning band).

segment_rate_limit_7d_stable() {
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

  _seg_icon=""
  _seg_attrs=""
  _seg_content="7d ${_r7_pct}% ${GL_SEP} ${_r7_days}d"

  if [ "$_sl_layout" = "zen" ]; then
    _seg_weight="recessed"
    _seg_min_tier="zen"
    _seg_group="ambient"
    _seg_group_fallback=""
  else
    # Classic: session row as tertiary. Require >=150 cols so we do not
    # overflow row 1 on tighter terminals (rate-5h + burn-rate + alerts +
    # 7d easily adds up past 140 in the warm band).
    [ "${_sl_cols:-0}" -lt 150 ] && return 1
    _seg_weight="tertiary"
    _seg_min_tier="full"
    _seg_group="session"
    _seg_group_fallback=""
  fi

  # Minimalist override: drop word label
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_content="${_r7_pct}% ${_r7_days}d"
  fi

  return 0
}
