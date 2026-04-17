#!/bin/sh
# segments/rate-limit-7d-stable.sh -- 7d rate-limit stable pill (zen Row 3 only)
# Self-gates on $_sl_layout and 7d threshold. Returns non-zero outside zen
# or when 7d >= 70% (that case is handled by segment_alerts_slot).

segment_rate_limit_7d_stable() {
  [ "$_sl_layout" != "zen" ] && return 1

  [ -z "$sl_rate_7d_pct" ] && return 1
  _r7_pct=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _r7_pct=-1
  [ "$_r7_pct" -lt 0 ] && return 1
  [ "$_r7_pct" -ge 70 ] && return 1

  # Days remaining
  _r7_now=$(date +%s)
  _r7_reset=$(( sl_rate_7d_reset_ts + 0 )) 2>/dev/null || _r7_reset=0
  _r7_secs=$(( _r7_reset - _r7_now ))
  [ "$_r7_secs" -lt 0 ] && _r7_secs=0
  _r7_days=$(( _r7_secs / 86400 ))

  _seg_weight="recessed"
  _seg_min_tier="zen"
  _seg_group="ambient"
  _seg_group_fallback=""   # does not render in classic
  _seg_icon=""
  _seg_attrs=""
  _seg_content="7d ${_r7_pct}% . ${_r7_days}d"

  return 0
}
