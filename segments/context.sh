#!/bin/sh
# segments/context.sh -- Context gauge with compaction countdown
# Reads: sl_used_pct, sl_ctx_size, sl_total_input_tokens, sl_duration_ms,
#         sl_exceeds_200k, _sl_tier
# Uses: format_tokens, GL_CTX, GL_WARN, GL_DOT_*

segment_context() {
  [ -z "$sl_used_pct" ] && return 1

  _seg_weight="primary"
  _seg_min_tier="micro"
  _seg_group="session"
  _seg_icon="$GL_CTX"
  _seg_attrs=""

  _cx_pct=$(( sl_used_pct + 0 )) 2>/dev/null || _cx_pct=0

  # Color threshold
  if [ "$_cx_pct" -ge 95 ]; then
    _seg_bg=$C_CTX_CRIT_BG; _seg_fg=$C_CTX_CRIT_FG
  elif [ "$_cx_pct" -ge 85 ]; then
    _seg_bg=$C_CTX_SOON_BG; _seg_fg=$C_CTX_SOON_FG
  elif [ "$_cx_pct" -ge 70 ]; then
    _seg_bg=$C_CTX_FILLING_BG; _seg_fg=$C_CTX_FILLING_FG
  elif [ "$_cx_pct" -ge 50 ]; then
    _seg_bg=$C_CTX_WARMING_BG; _seg_fg=$C_CTX_WARMING_FG
  else
    _seg_bg=$C_CTX_HEALTHY_BG; _seg_fg=$C_CTX_HEALTHY_FG
  fi

  # Attrs for critical
  if [ "$_cx_pct" -ge 95 ]; then
    if [ "$sl_exceeds_200k" = "true" ]; then
      _seg_attrs="bold blink"
    else
      _seg_attrs="bold"
    fi
  fi

  # --- Shared: dots, tokens, prefix (used by compact + full) ---
  _cx_dots=""
  _cx_tokens=""
  _cx_prefix=""
  _cx_size_val=$(( sl_ctx_size + 0 )) 2>/dev/null || _cx_size_val=0

  if [ "$_sl_tier" != "micro" ]; then
    _cx_filled=$(( _cx_pct / 20 ))
    [ "$_cx_filled" -gt 5 ] && _cx_filled=5
    _cx_empty=$(( 5 - _cx_filled ))
    _cx_i=0; while [ "$_cx_i" -lt "$_cx_filled" ]; do _cx_dots="${_cx_dots}${GL_DOT_FILLED}"; _cx_i=$((_cx_i+1)); done
    _cx_i=0; while [ "$_cx_i" -lt "$_cx_empty" ];  do _cx_dots="${_cx_dots}${GL_DOT_EMPTY}";  _cx_i=$((_cx_i+1)); done

    if [ "$_cx_size_val" -gt 0 ]; then
      _cx_used_tok=$(( _cx_size_val * _cx_pct / 100 ))
      format_tokens _cx_used_fmt "$_cx_used_tok"
      format_tokens _cx_max_fmt "$_cx_size_val"
      _cx_tokens=" ${_cx_used_fmt}/${_cx_max_fmt}"
    fi

    [ "$_cx_pct" -ge 95 ] && _cx_prefix="${GL_WARN} CTX! "
  fi

  # --- Build content by tier ---
  case "$_sl_tier" in
    micro)
      _seg_content="${_cx_pct}%"
      _seg_icon=""
      ;;
    compact)
      _seg_content="${_cx_prefix}${_cx_dots} ${_cx_pct}%${_cx_tokens}"
      ;;
    full|*)
      # Compaction countdown (full tier only)
      _cx_compact=""
      _cx_compact_pct="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-95}"
      _cx_dur_val=$(( sl_duration_ms + 0 )) 2>/dev/null || _cx_dur_val=0

      if [ "$_cx_dur_val" -ge 60000 ] && [ "$_cx_pct" -ge 50 ] && [ "$_cx_pct" -lt 95 ] && [ "$_cx_size_val" -gt 0 ]; then
        _cx_current=$(( _cx_size_val * _cx_pct / 100 ))
        _cx_target=$(( _cx_size_val * _cx_compact_pct / 100 ))
        _cx_remaining=$(( _cx_target - _cx_current ))
        if [ "$_cx_remaining" -gt 0 ] && [ "$_cx_current" -gt 0 ]; then
          _cx_ms_to_compact=$(( _cx_remaining * _cx_dur_val / _cx_current ))
          _cx_min_to_compact=$(( _cx_ms_to_compact / 60000 ))
          if [ "$_cx_min_to_compact" -gt 480 ]; then
            _cx_compact=" compact >8h"
          elif [ "$_cx_min_to_compact" -ge 60 ]; then
            _cx_hrs=$(( _cx_min_to_compact / 60 ))
            _cx_compact=" compact ~${_cx_hrs}h"
          elif [ "$_cx_min_to_compact" -gt 0 ]; then
            _cx_compact=" compact ~${_cx_min_to_compact}min"
          fi
        fi
      fi

      _seg_content="${_cx_prefix}${_cx_dots} ${_cx_pct}%${_cx_tokens}${_cx_compact}"
      ;;
  esac

  return 0
}
