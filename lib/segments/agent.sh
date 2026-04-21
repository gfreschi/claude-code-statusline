#!/bin/sh
# segments/agent.sh -- Agent name (conditional, extends model segment)
# Reads: sl_agent_name, sl_model_bg

segment_agent() {
  [ -z "$sl_agent_name" ] && return 1
  [ -z "$sl_model_bg" ] && return 1

  _seg_weight="primary"
  _seg_min_tier="full"
  _seg_group="session"
  _seg_icon=""
  _seg_attrs=""

  # Share model BG so orchestrator produces thin pipe (same-BG rule)
  _seg_bg=$sl_model_bg
  # Use model's own FG for readable contrast on colored BG
  _seg_fg=$sl_model_fg

  sl_truncate _ag_label "$sl_agent_name" 20
  _seg_content="$_ag_label"

  return 0
}
