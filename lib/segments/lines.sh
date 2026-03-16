#!/bin/sh
# segments/lines.sh -- Lines changed delta (conditional)
# Reads: sl_lines_added, sl_lines_removed

segment_lines() {
  _li_add=$(( sl_lines_added + 0 )) 2>/dev/null || _li_add=0
  _li_rem=$(( sl_lines_removed + 0 )) 2>/dev/null || _li_rem=0

  [ "$_li_add" -le 0 ] && [ "$_li_rem" -le 0 ] && return 1

  _seg_weight="tertiary"
  _seg_min_tier="full"
  _seg_group="workspace"
  _seg_icon="$GL_CODE"
  _seg_attrs=""
  _seg_bg=""

  _li_net=$(( _li_add - _li_rem ))

  if [ "$_li_net" -gt 0 ]; then
    _li_arrow="$GL_ARROW_UP"; _li_sign="+"; _seg_fg=$C_LINES_ADD
  elif [ "$_li_net" -lt 0 ]; then
    _li_arrow="$GL_ARROW_DOWN"; _li_sign=""; _seg_fg=$C_LINES_DEL
  else
    _li_arrow="$GL_ARROW_FLAT"; _li_sign=""; _seg_fg=$C_LINES_ZERO
  fi

  _seg_content="${_li_arrow}${_li_sign}${_li_net} (+${_li_add}/-${_li_rem})"

  return 0
}
