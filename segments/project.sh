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

  _seg_content="$sl_project"
  _seg_link_url="$sl_github_base_url"

  return 0
}
