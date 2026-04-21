#!/bin/sh
# segments/rate-limit.sh -- 5h rate-limit pill with configurable presets
# Reads: sl_rate_5h_pct, sl_rate_5h_reset_ts, sl_rate_7d_pct, _sl_layout, _sl_tier
# Env:   CLAUDE_STATUSLINE_RATE_STYLE (ember|bar|pill|minimal)

segment_rate_limit() {
  [ -z "$sl_rate_5h_pct" ] && return 1
  to_int _rl_5h "$sl_rate_5h_pct" -1
  [ "$_rl_5h" -lt 0 ] && return 1

  _rl_glyph=""
  _seg_group="session"
  _seg_min_tier="micro"
  _seg_attrs=""
  _seg_icon=""

  # Time-remaining computation. $_sl_now is memoized once in main.sh.
  _rl_now=$_sl_now
  to_int _rl_reset "$sl_rate_5h_reset_ts" 0
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

  # Sanity clamp: a 5h window is 18000s; anything past 6h of remaining time
  # means the upstream sent a garbage resets_at (demo fixtures, bad clock,
  # future epoch). Show "??" rather than "2284320h" of nonsense.
  if [ "$_rl_secs" -gt 21600 ]; then
    _rl_time="??"
  fi

  # State thresholds (based on USED %)
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

  # Ember glyph tracks state (empty for non-ember presets)
  if [ "$_rl_style" = "ember" ]; then
    case "$_rl_state" in
      ok)   _rl_glyph="$GL_BATT_FULL" ;;
      warm) _rl_glyph="$GL_BATT_MID" ;;
      crit) _rl_glyph="$GL_BATT_LOW" ;;
    esac
  fi

  # Leading glyph + space when set. Empty when preset has no glyph, so the
  # compact/micro override below doesn't produce a stray leading space.
  _rl_prefix=""
  [ -n "$_rl_glyph" ] && _rl_prefix="${_rl_glyph} "

  # Burn-in projection for crit when reset info is known. Only ember shows
  # the glyph, but any preset benefits from the projection on the crit row.
  _rl_burn_label=""
  if [ "$_rl_state" = "crit" ] && [ "$_rl_reset" -gt 0 ] && [ "$_rl_5h" -gt 0 ]; then
    _rl_elapsed=$(( 18000 - _rl_secs ))
    [ "$_rl_elapsed" -lt 1 ] && _rl_elapsed=1
    _rl_elapsed_pct=$(( _rl_elapsed * 100 / 18000 ))
    if [ "$_rl_5h" -gt "$_rl_elapsed_pct" ] && [ "$_rl_elapsed_pct" -gt 0 ]; then
      _rl_burn_sec=$(( _rl_elapsed * 100 / _rl_5h - _rl_elapsed ))
      [ "$_rl_burn_sec" -lt 0 ] && _rl_burn_sec=0
      _rl_burn_min=$(( _rl_burn_sec / 60 ))
      _rl_burn_label=" (burns in ${_rl_burn_min}m ${GL_UP})"
    fi
  fi

  # Preset rendering. USED% + "used" label is consistent across every preset
  # and state so readers never have to disambiguate whether the number means
  # budget used or budget remaining.
  case "$_rl_style" in
    ember)
      if [ "$_rl_state" = "crit" ]; then
        _seg_content="${_rl_prefix}${_rl_5h}% used ${GL_SEP} ${_rl_time} reset${_rl_burn_label}"
      else
        _seg_content="${_rl_prefix}${_rl_5h}% used ${GL_SEP} ${_rl_time} left"
      fi
      ;;
    minimal)
      _seg_content="${_rl_5h}% used ${GL_SEP} ${_rl_time}"
      ;;
    pill)
      to_int _rl_7d "$sl_rate_7d_pct" -1
      if [ "$_rl_7d" -ge 0 ]; then
        _seg_content="5h ${_rl_5h}% used ${GL_SEP} ${_rl_time} | 7d ${_rl_7d}% used"
      else
        _seg_content="5h ${_rl_5h}% used ${GL_SEP} ${_rl_time}"
      fi
      ;;
    bar)
      _rl_bar_filled=$(( _rl_5h / 10 ))
      [ "$_rl_bar_filled" -gt 10 ] && _rl_bar_filled=10
      _rl_bar=""
      _rl_bi=0; while [ "$_rl_bi" -lt "$_rl_bar_filled" ]; do _rl_bar="${_rl_bar}${GL_BLK_FILLED}"; _rl_bi=$((_rl_bi+1)); done
      _rl_bi=0; while [ "$_rl_bi" -lt $(( 10 - _rl_bar_filled )) ]; do _rl_bar="${_rl_bar}${GL_BLK_EMPTY}"; _rl_bi=$((_rl_bi+1)); done
      _seg_content="5h ${_rl_bar} ${_rl_5h}% used ${GL_SEP} ${_rl_time}"
      ;;
  esac

  # 7d inline for ember/minimal+warm in classic layout. Zen has a dedicated
  # Row 3 segment for 7d so the extra inline signal would be redundant there.
  if [ "$_rl_state" = "warm" ] && [ "$_sl_layout" != "zen" ] \
    && { [ "$_rl_style" = "ember" ] || [ "$_rl_style" = "minimal" ]; }; then
    to_int _rl_7d "$sl_rate_7d_pct" -1
    if [ "$_rl_7d" -ge 50 ]; then
      _seg_content="${_seg_content} ${GL_SEP} 7d ${_rl_7d}% used"
    fi
  fi

  # Compact tier: drop the "left"/"reset" suffix words for space, but keep
  # the burn-in projection on ember+crit - that is the most actionable
  # signal right before the user gets rate-limited.
  if [ "$_sl_tier" = "compact" ]; then
    if [ "$_rl_style" = "ember" ] && [ "$_rl_state" = "crit" ]; then
      _seg_content="${_rl_prefix}${_rl_5h}% used${_rl_burn_label}"
    else
      _seg_content="${_rl_prefix}${_rl_5h}% used ${GL_SEP} ${_rl_time}"
    fi
  fi

  # Micro tier: time dominates, percent is the tiebreaker in the segment
  # next to it. Drop the label to stay under 10 cols.
  if [ "$_sl_tier" = "micro" ]; then
    _seg_content="${_rl_prefix}${_rl_time}"
  fi

  # CLAUDE_STATUSLINE_MINIMAL=1 env var strips labels entirely (separate
  # concept from the `minimal` preset above).
  if [ "${CLAUDE_STATUSLINE_MINIMAL:-0}" = "1" ]; then
    _seg_content="${_rl_time} ${_rl_5h}%"
  fi

  return 0
}
