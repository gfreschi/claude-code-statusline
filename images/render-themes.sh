#!/bin/sh
# Helper script for VHS: showcases each theme's full color range
DIR="$(cd "$(dirname "$0")/.." && pwd)"

C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')

pos() { printf '\033[%d;%dH' "$1" "$2"; }

# Sonnet mid-session: shows model blue, warming context (gold bg),
# agent, burn rate, cache, lines added/removed, worktree, duration
json_sonnet='{"cwd":"/Users/dev/myproject","model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":58,"context_window_size":200000,"current_usage":{"input_tokens":90000,"output_tokens":20000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":60000},"total_input_tokens":116000,"total_output_tokens":25000},"cost":{"total_duration_ms":1200000,"total_lines_added":120,"total_lines_removed":35},"exceeds_200k_tokens":false,"agent":{"name":"feature-dev"},"worktree":{"name":"auth-refactor","branch":"feat/auth-refactor"}}'

# Opus critical: shows model gold, critical context (red bg, bold+blink),
# high duration (red), large line delta, worktree
json_critical='{"cwd":"/Users/dev/myproject","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":95,"context_window_size":200000,"current_usage":{"input_tokens":180000,"output_tokens":8000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":115000},"total_input_tokens":190000,"total_output_tokens":40000},"cost":{"total_duration_ms":5400000,"total_lines_added":340,"total_lines_removed":95},"exceeds_200k_tokens":true,"worktree":{"name":"auth-refactor","branch":"feat/auth-refactor"}}'

# Haiku light session: shows model cyan/green, healthy context (green bg),
# low duration, small line delta
json_haiku='{"cwd":"/Users/dev/myproject","model":{"id":"claude-haiku-4-5","display_name":"Claude Haiku 4.5"},"context_window":{"used_percentage":12,"context_window_size":200000,"current_usage":{"input_tokens":18000,"output_tokens":4000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":10000},"total_input_tokens":24000,"total_output_tokens":5000},"cost":{"total_duration_ms":90000,"total_lines_added":15,"total_lines_removed":3},"exceeds_200k_tokens":false}'

draw() {
  _d_theme="$1"
  _d_label="$2"
  _d_json="$3"
  _d_tag="$4"

  printf '\033[2J'
  pos 2 3
  printf "${C_BOLD}${C_WHITE}%s${C_RESET}  ${C_DIM}%s${C_RESET}" "$_d_label" "$_d_tag"
  pos 4 1
  echo "$_d_json" | COLUMNS=140 CLAUDE_STATUSLINE_THEME="$_d_theme" sh "$DIR/main.sh"
  sleep 2
}

clear

for theme in catppuccin-mocha dracula nord bluloco-dark; do
  case "$theme" in
    catppuccin-mocha) _rt_label="catppuccin-mocha (default)" ;;
    *) _rt_label="$theme" ;;
  esac

  draw "$theme" "$_rt_label" "$json_haiku"    "Haiku / healthy context"
  draw "$theme" "$_rt_label" "$json_sonnet"   "Sonnet / mid-session"
  draw "$theme" "$_rt_label" "$json_critical" "Opus / critical context"
done
