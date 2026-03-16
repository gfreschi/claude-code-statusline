#!/bin/sh
# segments/micro-location.sh -- Merged project + branch pill for micro tier
# Reads: sl_project, sl_branch, _sl_tier, GL_THIN_SEP

segment_micro_location() {
  [ "$_sl_tier" != "micro" ] && return 1
  [ -z "$sl_project" ] && [ -z "$sl_branch" ] && return 1

  _seg_weight="secondary"
  _seg_min_tier="micro"
  _seg_group="workspace"
  _seg_icon=""
  _seg_attrs=""
  _seg_bg=$C_MUTED_BG
  _seg_fg=$C_BASE_FG

  # Truncate project to ~8 chars
  _ml_proj="$sl_project"
  if [ ${#_ml_proj} -gt 8 ]; then
    _ml_proj="$(printf '%.6s' "$_ml_proj").."
  fi

  # Truncate branch to ~12 chars
  _ml_branch="${sl_branch:-}"
  if [ ${#_ml_branch} -gt 12 ]; then
    _ml_branch="$(printf '%.10s' "$_ml_branch").."
  fi

  if [ -n "$_ml_proj" ] && [ -n "$_ml_branch" ]; then
    _seg_content="${_ml_proj} ${GL_THIN_SEP} ${_ml_branch}"
  elif [ -n "$_ml_proj" ]; then
    _seg_content="$_ml_proj"
  else
    _seg_content="$_ml_branch"
  fi

  return 0
}
