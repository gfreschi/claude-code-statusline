#!/bin/sh
# segments/project.sh -- Project name with OSC 8 link
# Reads: sl_project, sl_github_base_url

segment_project() {
  [ -z "$sl_project" ] && return 1

  _seg_weight="secondary"
  _seg_min_tier="compact"
  _seg_group="workspace"
  _seg_icon="$GL_FOLDER"
  _seg_attrs=""
  _seg_bg=$C_MUTED_BG
  _seg_fg=$C_BASE_FG

  # Truncate in compact tier so long project names don't push the workspace
  # row past the terminal edge. Full/zen keep the unabbreviated name.
  if [ "$_sl_tier" = "compact" ]; then
    sl_truncate _pr_label "$sl_project" 20
    _seg_content="$_pr_label"
  else
    _seg_content="$sl_project"
  fi
  _seg_link_url="$sl_github_base_url"

  return 0
}
