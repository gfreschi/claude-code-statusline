#!/bin/sh
# segments/info-slot.sh -- Priority-rotating info segment (ambient / workspace fallback)
# Priority: output-style (non-default) > subdir > session-name > clock

segment_info_slot() {
  _is_hit=0

  # 1. Output style (non-default)
  if [ -n "$sl_output_style" ] && [ "$sl_output_style" != "default" ]; then
    _seg_content="${GL_SEP} ${sl_output_style}"
    _seg_icon=""
    _is_hit=1
  fi

  # 2. Subdir drift
  if [ "$_is_hit" -eq 0 ] && [ -n "$sl_project_dir" ] && [ -n "$sl_cwd" ] && [ "$sl_cwd" != "$sl_project_dir" ]; then
    case "$sl_cwd" in
      "$sl_project_dir"/*)
        _is_rel="${sl_cwd#$sl_project_dir/}"
        # Truncate to 20 chars with left-ellipsis
        _is_len=${#_is_rel}
        if [ "$_is_len" -gt 20 ]; then
          _is_rel="...$(printf '%s' "$_is_rel" | awk '{print substr($0, length($0)-16)}')"
        fi
        _seg_content="> ${_is_rel}"
        _seg_icon=""
        _is_hit=1
        ;;
    esac
  fi

  # 3. Session name
  if [ "$_is_hit" -eq 0 ] && [ -n "$sl_session_name" ]; then
    _seg_content="@${sl_session_name}"
    _seg_icon=""
    _is_hit=1
  fi

  # 4. Clock fallback
  if [ "$_is_hit" -eq 0 ]; then
    _seg_content="$(date +%H:%M)"
    _seg_icon="$GL_CLOCK"
    _is_hit=1
  fi

  _seg_weight="recessed"
  _seg_min_tier="full"
  _seg_group="ambient"
  _seg_group_fallback="workspace"
  _seg_attrs=""
  _seg_fg=""
  return 0
}
