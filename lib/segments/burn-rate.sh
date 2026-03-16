#!/bin/sh
# segments/burn-rate.sh -- Token consumption rate (conditional)
# Reads: sl_total_input_tokens, sl_duration_ms

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
    _seg_content="${_br_int}.${_br_dec}k tok/min"
  else
    _seg_content="${_br_tpm} tok/min"
  fi

  return 0
}
