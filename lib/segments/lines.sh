#!/bin/sh
# segments/lines.sh -- Lines changed delta (conditional)
# Reads: sl_lines_added, sl_lines_removed, SL_CAP_UNICODE

segment_lines() {
  to_int _li_add "$sl_lines_added" 0
  to_int _li_rem "$sl_lines_removed" 0

  [ "$_li_add" -le 0 ] && [ "$_li_rem" -le 0 ] && return 1

  _seg_weight="tertiary"
  _seg_min_tier="full"
  _seg_group="workspace"
  _seg_icon="$GL_CODE"
  _seg_attrs=""
  _seg_bg=""

  _li_net=$(( _li_add - _li_rem ))

  if [ "$_li_net" -gt 0 ]; then
    _li_arrow="$GL_ARROW_UP"; _seg_fg=$C_LINES_ADD
  elif [ "$_li_net" -lt 0 ]; then
    _li_arrow="$GL_ARROW_DOWN"; _seg_fg=$C_LINES_DEL
  else
    _li_arrow="$GL_ARROW_FLAT"; _seg_fg=$C_LINES_ZERO
  fi

  # Drop the redundant net integer: the signed breakdown below already
  # conveys direction + magnitude. In non-unicode fallback GL_ARROW_UP is
  # `+` and GL_ARROW_DOWN is `-`, which would collide with the breakdown's
  # leading signs - skip the arrow prefix there.
  if [ "$SL_CAP_UNICODE" -eq 1 ]; then
    _seg_content="${_li_arrow} +${_li_add} / -${_li_rem}"
  else
    _seg_content="+${_li_add} / -${_li_rem}"
  fi

  return 0
}
