#!/bin/sh
# main.sh -- Claude Code status line orchestrator
# Entry point: receives JSON via stdin, outputs ANSI-colored rows
# Row count depends on terminal width tier (full=2, compact/micro=1)

set -f  # disable globbing

SL_DIR="${0%/*}"
[ "$SL_DIR" = "$0" ] && SL_DIR="."
SL_LIB="$SL_DIR/lib"

# --- Config file sourcing (before reading other env vars) ---
_sl_cfg="${CLAUDE_STATUSLINE_CONFIG_FILE:-$HOME/.config/claude-statusline/config.sh}"
[ -r "$_sl_cfg" ] && . "$_sl_cfg"

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
_sl_layout="${CLAUDE_STATUSLINE_LAYOUT:-classic}"
case "$_sl_layout" in classic|zen) ;; *) _sl_layout=classic ;; esac

if [ "$_sl_layout" = "zen" ] && [ "$_sl_cols" -ge 140 ]; then
  _sl_tier="zen"
elif [ "$_sl_cols" -ge 120 ]; then
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
sl_rate_5h_pct="" ; sl_rate_5h_reset_ts=""
sl_rate_7d_pct="" ; sl_rate_7d_reset_ts=""
sl_output_style="" ; sl_session_name=""
sl_added_dirs_count="" ; sl_api_duration_ms=""
sl_project_dir=""

# Strip C0 control bytes + DEL from every string field at the jq boundary.
# Doing it here (once, in a single jq pass) costs nothing; doing it per
# segment per row pass would cost ~120 subshell forks per render. Numeric
# fields are laundered through `tostring` so they cannot carry escapes.
_jq_out=$(echo "$sl_input" | jq -r '
  def clean: if . == null then "" else (. | tostring | gsub("[[:cntrl:]]"; "")) end;
  "sl_cwd=" + ((.cwd // .workspace.current_dir // "") | clean | @sh),
  "sl_model_id=" + (.model.id | clean | @sh),
  "sl_model_name=" + (.model.display_name | clean | @sh),
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
  "sl_worktree_name=" + (.worktree.name | clean | @sh),
  "sl_agent_name=" + (.agent.name | clean | @sh),
  "sl_exceeds_200k=" + (.exceeds_200k_tokens // false | tostring | @sh),
  "sl_rate_5h_pct=" + (.rate_limits.five_hour.used_percentage // "" | tostring | @sh),
  "sl_rate_5h_reset_ts=" + (.rate_limits.five_hour.resets_at // "" | tostring | @sh),
  "sl_rate_7d_pct=" + (.rate_limits.seven_day.used_percentage // "" | tostring | @sh),
  "sl_rate_7d_reset_ts=" + (.rate_limits.seven_day.resets_at // "" | tostring | @sh),
  "sl_output_style=" + (.output_style.name | clean | @sh),
  "sl_session_name=" + (.session_name | clean | @sh),
  "sl_added_dirs_count=" + (.workspace.added_dirs // [] | length | tostring | @sh),
  "sl_api_duration_ms=" + (.cost.total_api_duration_ms // "" | tostring | @sh),
  "sl_project_dir=" + ((.workspace.project_dir // .cwd // "") | clean | @sh)
' 2>/dev/null) && eval "$_jq_out"

# Derived values
sl_model_short="${sl_model_name#Claude }"
[ -z "$sl_model_short" ] && sl_model_short="Claude"

sl_project=""
[ -n "$sl_cwd" ] && sl_project="${sl_cwd##*/}"

# Refresh git cache
. "$SL_LIB/cache.sh"
cache_refresh

# Memoize the current epoch. Several segments need it for "time until reset"
# math; without this each one forks `date +%s` independently, which adds up
# fast under zen's multi-pass layout.
_sl_now=$(date +%s)

# Push one burn-rate sample per render into the sparkline ring buffer.
# This MUST happen once per render, not per row group -- segment functions
# run 2-3x in zen layout as rows are assembled, which would triple-count.
if [ -n "$sl_duration_ms" ] && [ -n "$sl_total_input_tokens" ]; then
  to_int _sl_dur_ms "$sl_duration_ms" 0
  to_int _sl_in_tok "$sl_total_input_tokens" 0
  if [ "$_sl_dur_ms" -gt 0 ] && [ "$_sl_in_tok" -gt 0 ]; then
    _sl_tpm=$(( _sl_in_tok * 60000 / _sl_dur_ms ))
    sparkline_push "$_sl_tpm"
  fi
fi

# --- Source all segment files (defines functions, does not execute) ---
# Temporarily re-enable globbing for the segment glob
set +f
for _sf in "$SL_LIB"/segments/*.sh; do
  . "$_sf"
done
set -f

# --- Segment registration order ---
SL_SEGMENTS="segment_model segment_agent segment_context \
  segment_rate_limit segment_burn_rate segment_alerts_slot \
  segment_micro_location \
  segment_project segment_git segment_info_slot \
  segment_rate_limit_7d_stable \
  segment_lines segment_worktree segment_duration"

# Per-segment override (comma-separated basenames). Unknown names are silently
# dropped so `command not found` stderr noise never leaks into the status line.
if [ -n "${CLAUDE_STATUSLINE_SEGMENTS:-}" ]; then
  _sl_override=""
  _sl_old_ifs="$IFS"
  IFS=,
  for _sl_name in $CLAUDE_STATUSLINE_SEGMENTS; do
    _sl_name=$(printf '%s' "$_sl_name" | tr -d ' ')
    [ -z "$_sl_name" ] && continue
    _sl_fn="segment_${_sl_name}"
    if command -v "$_sl_fn" >/dev/null 2>&1; then
      _sl_override="${_sl_override} ${_sl_fn}"
    fi
  done
  IFS="$_sl_old_ifs"
  [ -n "$_sl_override" ] && SL_SEGMENTS="$_sl_override"
fi

# --- Render ---
# Skip empty rows. With CLAUDE_STATUSLINE_SEGMENTS the user may filter every
# segment in a group (e.g. all workspace segments); render_row leaves sl_row
# as "" in that case, and printing a blank newline would produce a visible
# gap in the terminal.
if [ "$_sl_tier" = "zen" ]; then
  reset_row
  render_row "session"
  row1="$sl_row"

  reset_row
  render_row "workspace"
  row2="$sl_row"

  reset_row
  render_row "ambient"
  row3="$sl_row"

  [ -n "$row1" ] && printf '%b\n' "$row1"
  [ -n "$row2" ] && printf '%b\n' "$row2"
  [ -n "$row3" ] && printf '%b\n' "$row3"
elif [ "$_sl_tier" = "full" ]; then
  reset_row
  render_row "session"
  row1="$sl_row"

  reset_row
  render_row "workspace"
  row2="$sl_row"

  [ -n "$row1" ] && printf '%b\n' "$row1"
  [ -n "$row2" ] && printf '%b\n' "$row2"
else
  reset_row
  render_row ""
  [ -n "$sl_row" ] && printf '%b\n' "$sl_row"
fi
