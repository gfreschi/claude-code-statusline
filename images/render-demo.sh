#!/bin/sh
# Helper script for VHS demo GIF -- showcases all features
DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Scene 1: Fresh Opus session -- model coloring, low context, basic segments
scene_fresh='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":8,"context_window_size":200000,"current_usage":{"input_tokens":12000,"output_tokens":2000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"total_input_tokens":12000,"total_output_tokens":2000},"cost":{"total_duration_ms":45000,"total_lines_added":0,"total_lines_removed":0},"exceeds_200k_tokens":false}'

# Scene 2: Sonnet mid-session -- different model color, agent, git changes, cache
scene_sonnet='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":42,"context_window_size":200000,"current_usage":{"input_tokens":65000,"output_tokens":15000,"cache_creation_input_tokens":8000,"cache_read_input_tokens":45000},"total_input_tokens":84000,"total_output_tokens":20000},"cost":{"total_duration_ms":480000,"total_lines_added":120,"total_lines_removed":35},"exceeds_200k_tokens":false,"agent":{"name":"code-reviewer"}}'

# Scene 3: Haiku quick task -- third model color, light usage
scene_haiku='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-haiku-4-5","display_name":"Claude Haiku 4.5"},"context_window":{"used_percentage":15,"context_window_size":200000,"current_usage":{"input_tokens":22000,"output_tokens":5000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":12000},"total_input_tokens":27000,"total_output_tokens":5000},"cost":{"total_duration_ms":120000,"total_lines_added":18,"total_lines_removed":4},"exceeds_200k_tokens":false}'

# Scene 4: Deep work -- high context, worktree, compaction ETA, all metrics
scene_deep='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":78,"context_window_size":200000,"current_usage":{"input_tokens":130000,"output_tokens":20000,"cache_creation_input_tokens":6000,"cache_read_input_tokens":95000},"total_input_tokens":156000,"total_output_tokens":32000},"cost":{"total_duration_ms":5400000,"total_lines_added":340,"total_lines_removed":85},"exceeds_200k_tokens":false,"agent":{"name":"feature-dev"},"worktree":{"name":"auth-refactor","branch":"worktree-auth-refactor"}}'

# Scene 5: Critical -- context near limit, bold+blink warning
scene_critical='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":96,"context_window_size":200000,"current_usage":{"input_tokens":185000,"output_tokens":6000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":120000},"total_input_tokens":192000,"total_output_tokens":42000},"cost":{"total_duration_ms":7800000,"total_lines_added":410,"total_lines_removed":190},"exceeds_200k_tokens":true,"worktree":{"name":"auth-refactor","branch":"worktree-auth-refactor"}}'

print_label() {
  printf '\033[1;97m %s\033[0m\n' "$1"
}

# --- Full tier scenes ---

clear
print_label "Opus -- fresh session"
echo "$scene_fresh" | COLUMNS=140 sh "$DIR/main.sh"
sleep 3

clear
print_label "Sonnet -- mid-session with agent and git activity"
echo "$scene_sonnet" | COLUMNS=140 sh "$DIR/main.sh"
sleep 3

clear
print_label "Haiku -- quick task"
echo "$scene_haiku" | COLUMNS=140 sh "$DIR/main.sh"
sleep 3

clear
print_label "Opus -- deep work with worktree and high context"
echo "$scene_deep" | COLUMNS=140 sh "$DIR/main.sh"
sleep 3

clear
print_label "Critical context -- bold+blink warning"
echo "$scene_critical" | COLUMNS=140 sh "$DIR/main.sh"
sleep 3

# --- Themes ---

clear
print_label "Themes: dracula"
echo "$scene_sonnet" | COLUMNS=140 CLAUDE_STATUSLINE_THEME=dracula sh "$DIR/main.sh"
sleep 2

clear
print_label "Themes: nord"
echo "$scene_sonnet" | COLUMNS=140 CLAUDE_STATUSLINE_THEME=nord sh "$DIR/main.sh"
sleep 2

clear
print_label "Themes: bluloco-dark"
echo "$scene_sonnet" | COLUMNS=140 CLAUDE_STATUSLINE_THEME=bluloco-dark sh "$DIR/main.sh"
sleep 2

# --- Adaptive tiers ---

clear
print_label "Compact tier (80-119 cols)"
echo "$scene_sonnet" | COLUMNS=100 sh "$DIR/main.sh"
sleep 2

clear
print_label "Micro tier (< 80 cols)"
echo "$scene_sonnet" | COLUMNS=60 sh "$DIR/main.sh"
sleep 3
