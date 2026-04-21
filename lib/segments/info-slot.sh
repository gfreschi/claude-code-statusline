#!/bin/sh
# segments/info-slot.sh -- Priority-rotating info segment (ambient / session fallback)
# Priority: output-style (non-default) > subdir > session-name > clock (zen only)
#
# Classic: renders on the session row (not workspace) so the clock/drift
# info sits near the model/context signals rather than jammed between
# branch and duration. The clock fallback is suppressed in classic to
# avoid a floating time-of-day next to workflow data.

segment_info_slot() {
  _is_hit=0

  # 1. Output style (non-default): ornamental middle-dot prefix.
  if [ -n "$sl_output_style" ] && [ "$sl_output_style" != "default" ]; then
    _seg_content="${GL_SEP} ${sl_output_style}"
    _seg_icon=""
    _is_hit=1
  fi

  # 2. Subdir drift: relative path from project root. Leading `/` reads as
  # "below project root". When the path is long, the left side is replaced
  # by GL_ELLIPSIS to keep the tail (which is the part the user navigated
  # to) visible.
  if [ "$_is_hit" -eq 0 ] && [ -n "$sl_project_dir" ] && [ -n "$sl_cwd" ] && [ "$sl_cwd" != "$sl_project_dir" ]; then
    case "$sl_cwd" in
      "$sl_project_dir"/*)
        _is_rel="${sl_cwd#$sl_project_dir/}"
        _is_len=${#_is_rel}
        if [ "$_is_len" -gt 20 ]; then
          _is_rel="${GL_ELLIPSIS}$(printf '%s' "$_is_rel" | awk '{print substr($0, length($0)-16)}')"
        fi
        _seg_content="/${_is_rel}"
        _seg_icon=""
        _is_hit=1
        ;;
    esac
  fi

  # 3. Session name: @-prefixed, kept distinctive.
  if [ "$_is_hit" -eq 0 ] && [ -n "$sl_session_name" ]; then
    _seg_content="@${sl_session_name}"
    _seg_icon=""
    _is_hit=1
  fi

  # 4. Clock fallback: zen only. In classic the ambient row does not exist,
  # and a floating clock next to workflow data reads as stray rather than
  # ambient - suppress it.
  if [ "$_is_hit" -eq 0 ] && [ "$_sl_layout" = "zen" ]; then
    _seg_content="$(date +%H:%M)"
    _seg_icon="$GL_CLOCK"
    _is_hit=1
  fi

  [ "$_is_hit" -eq 0 ] && return 1

  _seg_weight="recessed"
  _seg_min_tier="full"
  _seg_group="ambient"
  _seg_group_fallback="session"
  _seg_attrs=""
  _seg_fg=""
  return 0
}
