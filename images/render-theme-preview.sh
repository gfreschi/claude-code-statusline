#!/bin/sh
# Renders 3 states for a single theme (used by per-theme VHS tapes)
# Usage: sh render-theme-preview.sh <theme-name>
DIR="$(cd "$(dirname "$0")/.." && pwd)"
THEME="${1:?Usage: sh render-theme-preview.sh <theme-name>}"

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

json_haiku='{"cwd":"/Users/dev/myproject","model":{"id":"claude-haiku-4-5","display_name":"Claude Haiku 4.5"},"context_window":{"used_percentage":12,"context_window_size":200000,"current_usage":{"input_tokens":18000,"output_tokens":4000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":10000},"total_input_tokens":24000,"total_output_tokens":5000},"cost":{"total_duration_ms":90000,"total_lines_added":15,"total_lines_removed":3},"exceeds_200k_tokens":false}'

json_sonnet='{"cwd":"/Users/dev/myproject","model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":58,"context_window_size":200000,"current_usage":{"input_tokens":90000,"output_tokens":20000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":60000},"total_input_tokens":116000,"total_output_tokens":25000},"cost":{"total_duration_ms":1200000,"total_lines_added":120,"total_lines_removed":35},"exceeds_200k_tokens":false,"agent":{"name":"feature-dev"},"worktree":{"name":"auth-refactor","branch":"feat/auth-refactor"}}'

json_opus='{"cwd":"/Users/dev/myproject","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":95,"context_window_size":200000,"current_usage":{"input_tokens":180000,"output_tokens":8000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":115000},"total_input_tokens":190000,"total_output_tokens":40000},"cost":{"total_duration_ms":5400000,"total_lines_added":340,"total_lines_removed":95},"exceeds_200k_tokens":true,"worktree":{"name":"auth-refactor","branch":"feat/auth-refactor"}}'

draw() {
  _d_tag="$1"
  _d_json="$2"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}%s${C_RESET}" "$_d_tag"
  pos 4 1
  echo "$_d_json" | COLUMNS=140 CLAUDE_STATUSLINE_THEME="$THEME" sh "$DIR/main.sh"
  sleep 3
}

clear
draw "Haiku / healthy context"  "$json_haiku"
draw "Sonnet / mid-session"     "$json_sonnet"
draw "Opus / critical context"  "$json_opus"
