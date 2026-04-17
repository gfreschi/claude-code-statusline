#!/bin/sh
# segments/burn-rate.sh -- Token consumption rate (conditional)
# Reads: sl_total_input_tokens, sl_duration_ms, _sl_tier

segment_burn_rate() {
  _br_dur=$(( sl_duration_ms + 0 )) 2>/dev/null || _br_dur=0
  _br_total=$(( sl_total_input_tokens + 0 )) 2>/dev/null || _br_total=0

  # Only show after 60s of data
  [ "$_br_dur" -lt 60000 ] && return 1
  [ "$_br_total" -le 0 ] && return 1

  _seg_weight="tertiary"
  _seg_min_tier="full"
  _seg_group="session"
  _seg_icon="$GL_BURN"
  _seg_attrs=""
  _seg_bg="" ; _seg_fg=""

  _br_tpm=$(( _br_total * 60000 / _br_dur ))

  if [ "$_br_tpm" -ge 1000 ]; then
    _br_int=$(( _br_tpm / 1000 ))
    _br_dec=$(( (_br_tpm % 1000) / 100 ))
    _br_text="${_br_int}.${_br_dec}k tok/min"
  else
    _br_text="${_br_tpm} tok/min"
  fi

  # Braille sparkline tail: push latest tpm into ring buffer and render
  # 4+ samples as braille chars in full/zen tiers only.
  sparkline_push "$_br_tpm"
  _br_spark=""
  if [ "$_sl_tier" = "full" ] || [ "$_sl_tier" = "zen" ]; then
    _br_history=$(sparkline_read)
    if [ -n "$_br_history" ]; then
      _br_n=$(printf '%s\n' "$_br_history" | tr ',' '\n' | wc -l | tr -d ' ')
      if [ "$_br_n" -ge 4 ]; then
        _br_max=$(printf '%s\n' "$_br_history" | tr ',' '\n' | sort -n | tail -1)
        case "$_br_max" in ''|*[!0-9]*) _br_max=1 ;; esac
        [ "$_br_max" -lt 1 ] 2>/dev/null && _br_max=1
        _br_spark=" "
        _br_oifs=$IFS
        IFS=','
        for _br_v in $_br_history; do
          case "$_br_v" in ''|*[!0-9]*) _br_v=0 ;; esac
          _br_bucket=$(( _br_v * 8 / _br_max ))
          [ "$_br_bucket" -gt 8 ] && _br_bucket=8
          [ "$_br_bucket" -lt 0 ] && _br_bucket=0
          eval "_br_spark=\"\${_br_spark}\$GL_BRL_${_br_bucket}\""
        done
        IFS=$_br_oifs
      fi
    fi
  fi

  _seg_content="${_br_text}${_br_spark}"

  return 0
}
