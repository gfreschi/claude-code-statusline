#!/bin/sh
# Helper script for VHS screenshots -- renders all themes
DIR="$(cd "$(dirname "$0")/.." && pwd)"

json='{"cwd":"/Users/test/dev/myproject","model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":75,"context_window_size":200000,"current_usage":{"input_tokens":120000,"output_tokens":18000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":80000},"total_input_tokens":150000,"total_output_tokens":30000},"cost":{"total_duration_ms":3900000,"total_lines_added":80,"total_lines_removed":6},"exceeds_200k_tokens":false,"agent":{"name":"code-reviewer"},"worktree":{"name":"auth-refactor"}}'

clear
for theme in catppuccin-mocha dracula nord bluloco-dark; do
  case "$theme" in
    catppuccin-mocha) label="catppuccin-mocha (default)" ;;
    *) label="$theme" ;;
  esac
  printf '\033[1;97m %s\033[0m\n' "$label"
  echo "$json" | COLUMNS=140 CLAUDE_STATUSLINE_THEME="$theme" sh "$DIR/main.sh"
  printf '\n'
done
