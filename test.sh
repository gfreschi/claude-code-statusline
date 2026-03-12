#!/bin/sh
# test.sh -- Test harness for statusline
# Usage: sh test.sh [scenario] [theme]
# Scenarios: minimal, mid, full, critical
# Themes: catppuccin-mocha (default), bluloco-dark, dracula, nord
# Tiers are tested by overriding COLUMNS

DIR="$(cd "$(dirname "$0")" && pwd)"

scenario="${1:-minimal}"
theme="${2:-}"

# Export theme if specified
[ -n "$theme" ] && export CLAUDE_STATUSLINE_THEME="$theme"

# JSON payloads
case "$scenario" in
  minimal)
    json='{"cwd":"/Users/test/dev/myproject","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":2,"context_window_size":200000,"current_usage":{"input_tokens":4000,"output_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"total_input_tokens":4000,"total_output_tokens":200},"cost":{"total_duration_ms":15000,"total_lines_added":0,"total_lines_removed":0},"exceeds_200k_tokens":false}'
    ;;
  mid)
    json='{"cwd":"/Users/test/dev/myproject","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":52,"context_window_size":200000,"current_usage":{"input_tokens":80000,"output_tokens":12000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000},"total_input_tokens":104000,"total_output_tokens":20000},"cost":{"total_duration_ms":300000,"total_lines_added":56,"total_lines_removed":12},"exceeds_200k_tokens":false,"agent":{"name":"security-reviewer"}}'
    ;;
  full)
    json='{"cwd":"/Users/test/dev/myproject","model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":75,"context_window_size":200000,"current_usage":{"input_tokens":120000,"output_tokens":18000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":80000},"total_input_tokens":150000,"total_output_tokens":30000},"cost":{"total_duration_ms":3900000,"total_lines_added":80,"total_lines_removed":6},"exceeds_200k_tokens":false,"agent":{"name":"security-reviewer"},"worktree":{"name":"auth-refactor","branch":"worktree-auth-refactor"}}'
    ;;
  critical)
    json='{"cwd":"/Users/test/dev/myproject","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":96,"context_window_size":200000,"current_usage":{"input_tokens":180000,"output_tokens":8000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":100000},"total_input_tokens":192000,"total_output_tokens":40000},"cost":{"total_duration_ms":7200000,"total_lines_added":200,"total_lines_removed":150},"exceeds_200k_tokens":true,"worktree":{"name":"auth-refactor","branch":"worktree-auth-refactor"}}'
    ;;
  *)
    echo "Unknown scenario: $scenario" >&2
    echo "Usage: sh test.sh [minimal|mid|full|critical] [theme]" >&2
    exit 1
    ;;
esac

# Test all three tiers
echo "=== Scenario: $scenario | Theme: ${CLAUDE_STATUSLINE_THEME:-catppuccin-mocha} ==="
echo ""
echo "--- Full tier (COLUMNS=140) ---"
echo "$json" | COLUMNS=140 sh "$DIR/main.sh"
echo ""
echo "--- Compact tier (COLUMNS=100) ---"
echo "$json" | COLUMNS=100 sh "$DIR/main.sh"
echo ""
echo "--- Micro tier (COLUMNS=60) ---"
echo "$json" | COLUMNS=60 sh "$DIR/main.sh"
echo ""
