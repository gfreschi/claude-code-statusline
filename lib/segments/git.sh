#!/bin/sh
# segments/git.sh -- Branch + dirty + ahead/behind + stash + OSC 8 link
# Reads: sl_branch, sl_is_detached, sl_is_dirty, sl_ahead, sl_behind,
#         sl_stash_count, sl_github_base_url, _sl_tier,
#         sl_git_staged, sl_git_unstaged, sl_git_untracked

segment_git() {
  [ -z "$sl_branch" ] && return 1

  # Mid-merge / mid-rebase override: replace branch display with loud status.
  # Uses tertiary weight so _seg_fg override lands (secondary ignores fg).
  if [ -n "$sl_git_op" ]; then
    _seg_icon="$GL_WARN"
    _seg_content="! ${sl_git_op}"
    [ -n "$sl_git_step" ] && _seg_content="${_seg_content} ${sl_git_step}"
    _seg_attrs="bold"
    _seg_fg=$C_CTX_CRIT_FG
    _seg_detail=""
    _seg_weight="tertiary"
    _seg_min_tier="compact"
    _seg_group="workspace"
    return 0
  fi

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
      # Split dirty indicator: staged / unstaged / untracked (plus ahead/behind/stash)
      _gs_detail=""
      if [ -n "$sl_git_staged" ] && [ "$sl_git_staged" -gt 0 ] 2>/dev/null; then
        _gs_detail="${_gs_detail}+${sl_git_staged} "
      fi
      if [ -n "$sl_git_unstaged" ] && [ "$sl_git_unstaged" -gt 0 ] 2>/dev/null; then
        _gs_detail="${_gs_detail}-${sl_git_unstaged} "
      fi
      if [ -n "$sl_git_untracked" ] && [ "$sl_git_untracked" -gt 0 ] 2>/dev/null; then
        _gs_detail="${_gs_detail}?${sl_git_untracked} "
      fi
      [ "$sl_ahead" -gt 0 ] 2>/dev/null && _gs_detail="${_gs_detail}^${sl_ahead} "
      [ "$sl_behind" -gt 0 ] 2>/dev/null && _gs_detail="${_gs_detail}v${sl_behind} "
      [ "$sl_stash_count" -gt 0 ] 2>/dev/null && _gs_detail="${_gs_detail}*${sl_stash_count} "
      if [ "$sl_git_fork" = "1" ]; then
        _gs_detail="${_gs_detail}${GL_FORK} fork "
      fi
      _seg_detail="${_gs_detail% }"
      ;;
  esac

  return 0
}
