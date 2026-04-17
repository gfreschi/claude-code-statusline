#!/bin/sh
# segments/rate-limit.sh -- 5h rate-limit pill with configurable presets
# Reads: sl_rate_5h_pct, sl_rate_5h_reset_ts, sl_rate_7d_pct, _sl_layout, _sl_tier
# Env:   CLAUDE_STATUSLINE_RATE_STYLE (ember|bar|pill|minimal)

segment_rate_limit() {
  [ -z "$sl_rate_5h_pct" ] && return 1
  _rl_5h=$(( sl_rate_5h_pct + 0 )) 2>/dev/null || _rl_5h=-1
  [ "$_rl_5h" -lt 0 ] && return 1

  _rl_glyph=""
  _seg_group="session"
  _seg_min_tier="micro"
  _seg_attrs=""
  _seg_icon=""

  # Time-remaining computation
  _rl_now=$(date +%s)
  _rl_reset=$(( sl_rate_5h_reset_ts + 0 )) 2>/dev/null || _rl_reset=0
  _rl_secs=$(( _rl_reset - _rl_now ))
  [ "$_rl_secs" -lt 0 ] && _rl_secs=0
  _rl_min=$(( _rl_secs / 60 ))
  _rl_h=$(( _rl_min / 60 ))
  _rl_m=$(( _rl_min % 60 ))

  # Format "XhYm" or "Ym" (no leading hour when zero)
  if [ "$_rl_h" -gt 0 ]; then
    _rl_time="${_rl_h}h${_rl_m}m"
  else
    _rl_time="${_rl_m}m"
  fi

  # State thresholds
  if [ "$_rl_5h" -ge 85 ]; then
    _rl_state="crit"
  elif [ "$_rl_5h" -ge 50 ]; then
    _rl_state="warm"
  else
    _rl_state="ok"
  fi

  # Weight + color
  case "$_rl_state" in
    crit) _seg_weight="primary"; _seg_bg=$C_CTX_CRIT_BG; _seg_fg=$C_CTX_CRIT_FG ; _seg_attrs="bold" ;;
    warm) _seg_weight="tertiary"; _seg_fg=$C_DUR_MED ;;
    ok)   _seg_weight="tertiary"; _seg_fg=$C_DUR_LOW ;;
  esac

  # Preset selection
  _rl_style="${CLAUDE_STATUSLINE_RATE_STYLE:-ember}"
  case "$_rl_style" in ember|bar|pill|minimal) ;; *) _rl_style=ember ;; esac

  # Preset rendering
  case "$_rl_style" in
    ember)
      case "$_rl_state" in
        ok)   _rl_glyph="$GL_BATT_FULL" ;;
        warm) _rl_glyph="$GL_BATT_MID" ;;
        crit) _rl_glyph="$GL_BATT_LOW" ;;
      esac
      _rl_left=$(( 100 - _rl_5h ))
      if [ "$_rl_state" = "crit" ]; then
        # ETA for "burns in Xm" when pace > 1.0
        # Simple model: if used > elapsed percent, show burn ETA.
        _rl_burn_label=""
        if [ "$_rl_reset" -gt 0 ] && [ "$_rl_5h" -gt 0 ]; then
          # elapsed_sec = 18000 - remaining_sec; elapsed_pct = elapsed_sec*100/18000
          _rl_elapsed=$(( 18000 - _rl_secs ))
          [ "$_rl_elapsed" -lt 1 ] && _rl_elapsed=1
          _rl_elapsed_pct=$(( _rl_elapsed * 100 / 18000 ))
          if [ "$_rl_5h" -gt "$_rl_elapsed_pct" ] && [ "$_rl_elapsed_pct" -gt 0 ]; then
            # projected seconds to 100 at current rate: 18000 * 100 / _rl_5h * (elapsed/18000)
            _rl_burn_sec=$(( _rl_elapsed * 100 / _rl_5h - _rl_elapsed ))
            [ "$_rl_burn_sec" -lt 0 ] && _rl_burn_sec=0
            _rl_burn_min=$(( _rl_burn_sec / 60 ))
            _rl_burn_label=" burns in ${_rl_burn_min}m ${GL_UP}"
          fi
        fi
        _seg_content="${_rl_glyph}${_rl_burn_label} ${_rl_5h}% left . ${_rl_time} reset"
      elif [ "$_rl_state" = "warm" ]; then
        _rl_7d_inline=""
        _rl_7d=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _rl_7d=-1
        if [ "$_sl_layout" != "zen" ] && [ "$_rl_7d" -ge 50 ]; then
          _rl_7d_inline=" . 7d ${_rl_7d}%"
        fi
        _seg_content="${_rl_glyph} ${_rl_time} left . ${_rl_5h}%${_rl_7d_inline}"
      else
        _seg_content="${_rl_glyph} ${_rl_time} left . ${_rl_left}%"
      fi
      ;;
    minimal)
      _seg_content="${_rl_time} . ${_rl_5h}%"
      ;;
    pill)
      _rl_7d=$(( sl_rate_7d_pct + 0 )) 2>/dev/null || _rl_7d=-1
      if [ "$_rl_7d" -ge 0 ]; then
        _seg_content="5h ${_rl_5h}% . ${_rl_time} | 7d ${_rl_7d}%"
      else
        _seg_content="5h ${_rl_5h}% . ${_rl_time}"
      fi
      ;;
    bar)
      # position = elapsed%, fill = _rl_5h
      _rl_bar_filled=$(( _rl_5h / 10 ))
      [ "$_rl_bar_filled" -gt 10 ] && _rl_bar_filled=10
      _rl_bar=""
      _rl_bi=0; while [ "$_rl_bi" -lt "$_rl_bar_filled" ]; do _rl_bar="${_rl_bar}${GL_BLK_FILLED}"; _rl_bi=$((_rl_bi+1)); done
      _rl_bi=0; while [ "$_rl_bi" -lt $(( 10 - _rl_bar_filled )) ]; do _rl_bar="${_rl_bar}${GL_BLK_EMPTY}"; _rl_bi=$((_rl_bi+1)); done
      _seg_content="5h ${_rl_bar} ${_rl_5h}% . ${_rl_time}"
      ;;
  esac

  # Compact tier: drop 7d inline
  if [ "$_sl_tier" = "compact" ]; then
    _seg_content="${_rl_glyph:-} ${_rl_time} . ${_rl_5h}%"
  fi
  # Micro tier
  if [ "$_sl_tier" = "micro" ]; then
    _seg_content="${_rl_glyph:-} ${_rl_time}"
  fi

  return 0
}
