#!/bin/sh
# main.sh -- Claude Code status line orchestrator
# Entry point: receives JSON via stdin, outputs ANSI-colored rows
# Row count depends on terminal width tier (full=2, compact/micro=1)

set -f  # disable globbing

SL_DIR="${0%/*}"
[ "$SL_DIR" = "$0" ] && SL_DIR="."
SL_LIB="$SL_DIR/lib"

# Read JSON input
sl_input=$(cat)

# Source foundation
. "$SL_LIB/theme.sh"
. "$SL_LIB/render.sh"

# Initialize capabilities and platform
detect_capabilities
detect_platform

# --- Tier detection ---
_sl_cols="${COLUMNS:-120}"

if [ "$_sl_cols" -ge 120 ]; then
  _sl_tier="full"
elif [ "$_sl_cols" -ge 80 ]; then
  _sl_tier="compact"
else
  _sl_tier="micro"
fi

# --- Extract all fields from JSON (single jq call) ---
sl_cwd="" ; sl_model_id="" ; sl_model_name=""
sl_used_pct="" ; sl_ctx_size=""
sl_input_tokens="" ; sl_output_tokens=""
sl_cache_create_tokens="" ; sl_cache_read_tokens=""
sl_total_input_tokens="" ; sl_total_output_tokens=""
sl_duration_ms="" ; sl_lines_added="" ; sl_lines_removed=""
sl_worktree_name="" ; sl_agent_name="" ; sl_exceeds_200k=""

_jq_out=$(echo "$sl_input" | jq -r '
  "sl_cwd=" + (.cwd // .workspace.current_dir // "" | @sh),
  "sl_model_id=" + (.model.id // "" | @sh),
  "sl_model_name=" + (.model.display_name // "" | @sh),
  "sl_used_pct=" + (.context_window.used_percentage // "" | tostring | @sh),
  "sl_ctx_size=" + (.context_window.context_window_size // "" | tostring | @sh),
  "sl_input_tokens=" + (.context_window.current_usage.input_tokens // "" | tostring | @sh),
  "sl_output_tokens=" + (.context_window.current_usage.output_tokens // "" | tostring | @sh),
  "sl_cache_create_tokens=" + (.context_window.current_usage.cache_creation_input_tokens // "" | tostring | @sh),
  "sl_cache_read_tokens=" + (.context_window.current_usage.cache_read_input_tokens // "" | tostring | @sh),
  "sl_total_input_tokens=" + (.context_window.total_input_tokens // "" | tostring | @sh),
  "sl_total_output_tokens=" + (.context_window.total_output_tokens // "" | tostring | @sh),
  "sl_duration_ms=" + (.cost.total_duration_ms // "" | tostring | @sh),
  "sl_lines_added=" + (.cost.total_lines_added // "" | tostring | @sh),
  "sl_lines_removed=" + (.cost.total_lines_removed // "" | tostring | @sh),
  "sl_worktree_name=" + (.worktree.name // "" | @sh),
  "sl_agent_name=" + (.agent.name // "" | @sh),
  "sl_exceeds_200k=" + (.exceeds_200k_tokens // false | tostring | @sh)
' 2>/dev/null) && eval "$_jq_out"

# Derived values
sl_model_short="${sl_model_name#Claude }"
[ -z "$sl_model_short" ] && sl_model_short="Claude"

sl_project=""
[ -n "$sl_cwd" ] && sl_project="${sl_cwd##*/}"

# Refresh git cache
. "$SL_LIB/cache.sh"
cache_refresh

# --- Source all segment files (defines functions, does not execute) ---
# Temporarily re-enable globbing for the segment glob
set +f
for _sf in "$SL_LIB"/segments/*.sh; do
  . "$_sf"
done
set -f

# --- Segment registration order ---
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_burn_rate segment_cache_stats \
  segment_micro_location \
  segment_project segment_git segment_lines \
  segment_worktree segment_duration"

# --- Render ---
if [ "$_sl_tier" = "full" ]; then
  reset_row
  render_row "session"
  row1="$sl_row"

  reset_row
  render_row "workspace"
  row2="$sl_row"

  printf '%b\n' "$row1"
  printf '%b\n' "$row2"
else
  reset_row
  render_row ""
  printf '%b\n' "$sl_row"
fi
