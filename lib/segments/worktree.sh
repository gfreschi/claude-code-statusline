#!/bin/sh
# segments/worktree.sh -- Worktree indicator (conditional)
# Reads: sl_worktree_name

segment_worktree() {
  [ -z "$sl_worktree_name" ] && return 1

  _seg_weight="tertiary"
  _seg_min_tier="full"
  _seg_group="workspace"
  _seg_icon="$GL_WORKTREE"
  _seg_attrs=""
  _seg_bg=""
  _seg_fg=$C_WORKTREE_FG

  sl_truncate _wt_label "$sl_worktree_name" 20
  _seg_content="wt:${_wt_label}"

  return 0
}
