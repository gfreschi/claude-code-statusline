#!/bin/sh
# segments/git.sh -- Branch + dirty + ahead/behind + stash + OSC 8 link
# Reads: sl_branch, sl_is_detached, sl_is_dirty, sl_ahead, sl_behind,
#         sl_stash_count, sl_github_base_url, _sl_tier

segment_git() {
  [ -z "$sl_branch" ] && return 1

  _seg_weight="secondary"
  _seg_min_tier="compact"
  _seg_group="workspace"
  _seg_attrs=""
  _seg_bg=$C_MUTED_BG
  _seg_fg=$C_BASE_FG

  # Icon
  if [ "$sl_is_detached" -eq 1 ]; then
    _seg_icon="$GL_DETACHED"
  elif [ "$sl_is_dirty" -eq 1 ]; then
    _seg_icon="$GL_DIRTY"
  else
    _seg_icon="$GL_BRANCH"
  fi

  # Branch link URL for orchestrator to wrap via _seg_link_url
  if [ -n "$sl_github_base_url" ] && [ "$sl_is_detached" -eq 0 ]; then
    _seg_link_url="${sl_github_base_url}/tree/${sl_branch}"
  fi

  _seg_content="$sl_branch"

  case "$_sl_tier" in
    full|*)
      # Detail suffix rendered in dim by orchestrator via _seg_detail
      _seg_detail=""
      [ "$sl_ahead" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail}^${sl_ahead}"
      [ "$sl_behind" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail}v${sl_behind}"
      [ "$sl_stash_count" -gt 0 ] 2>/dev/null && _seg_detail="${_seg_detail} *${sl_stash_count}"
      ;;
  esac

  return 0
}
