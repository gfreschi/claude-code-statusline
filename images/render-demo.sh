#!/bin/sh
# Helper script for VHS demo -- mocks Claude Code UI with status line
DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Terminal dimensions (must match demo.tape)
COLS=140
ROWS=24

# Colors (printf to get real escape bytes, not literal \033)
C_RESET=$(printf '\033[0m')
C_DIM=$(printf '\033[2m')
C_BOLD=$(printf '\033[1m')
C_WHITE=$(printf '\033[97m')
C_CYAN=$(printf '\033[36m')
C_GREEN=$(printf '\033[32m')
C_YELLOW=$(printf '\033[33m')
C_GRAY=$(printf '\033[90m')

# Position cursor at row,col (1-based)
pos() { printf '\033[%d;%dH' "$1" "$2"; }

# Clear screen and draw a scene
# Usage: draw_scene <status_json> [theme]
draw_scene() {
  _ds_json="$1"
  _ds_theme="${2:-}"
  _ds_prompt="$3"
  _ds_response="$4"

  printf '\033[2J'
  pos 1 1

  # Mock Claude Code header
  printf "${C_DIM}%s${C_RESET}\n" "╭──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮"

  # Prompt line
  pos 3 3
  printf "${C_BOLD}${C_GREEN}>${C_RESET} ${C_WHITE}%s${C_RESET}" "$_ds_prompt"

  # Response
  _ds_line=5
  _ds_old_ifs="$IFS"
  IFS='|'
  for _ds_part in $_ds_response; do
    pos "$_ds_line" 3
    printf "${C_RESET}%s" "$_ds_part"
    _ds_line=$(( _ds_line + 1 ))
  done
  IFS="$_ds_old_ifs"

  # Separator above status line
  pos $(( ROWS - 3 )) 1
  printf "${C_DIM}%s${C_RESET}" "╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯"

  # Status line at bottom
  pos $(( ROWS - 1 )) 1
  if [ -n "$_ds_theme" ]; then
    printf '%s' "$_ds_json" | COLUMNS="$COLS" CLAUDE_STATUSLINE_THEME="$_ds_theme" sh "$DIR/main.sh"
  else
    printf '%s' "$_ds_json" | COLUMNS="$COLS" sh "$DIR/main.sh"
  fi
}

# --- JSON payloads for each scene ---

json_fresh='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":5,"context_window_size":200000,"current_usage":{"input_tokens":8000,"output_tokens":1500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"total_input_tokens":8000,"total_output_tokens":1500},"cost":{"total_duration_ms":30000,"total_lines_added":0,"total_lines_removed":0},"exceeds_200k_tokens":false}'

json_exploring='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":22,"context_window_size":200000,"current_usage":{"input_tokens":35000,"output_tokens":8000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":18000},"total_input_tokens":44000,"total_output_tokens":10000},"cost":{"total_duration_ms":180000,"total_lines_added":0,"total_lines_removed":0},"exceeds_200k_tokens":false,"agent":{"name":"code-explorer"}}'

json_implementing='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":48,"context_window_size":200000,"current_usage":{"input_tokens":72000,"output_tokens":18000,"cache_creation_input_tokens":6000,"cache_read_input_tokens":52000},"total_input_tokens":96000,"total_output_tokens":22000},"cost":{"total_duration_ms":600000,"total_lines_added":145,"total_lines_removed":32},"exceeds_200k_tokens":false,"agent":{"name":"feature-dev"},"worktree":{"name":"add-rate-limiting","branch":"feat/add-rate-limiting"}}'

json_reviewing='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":71,"context_window_size":200000,"current_usage":{"input_tokens":115000,"output_tokens":22000,"cache_creation_input_tokens":4000,"cache_read_input_tokens":85000},"total_input_tokens":142000,"total_output_tokens":30000},"cost":{"total_duration_ms":2700000,"total_lines_added":280,"total_lines_removed":65},"exceeds_200k_tokens":false,"agent":{"name":"code-reviewer"},"worktree":{"name":"add-rate-limiting","branch":"feat/add-rate-limiting"}}'

json_critical='{"cwd":"/Users/dev/api-gateway","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":94,"context_window_size":200000,"current_usage":{"input_tokens":178000,"output_tokens":8000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":110000},"total_input_tokens":188000,"total_output_tokens":38000},"cost":{"total_duration_ms":5400000,"total_lines_added":340,"total_lines_removed":95},"exceeds_200k_tokens":true,"worktree":{"name":"add-rate-limiting","branch":"feat/add-rate-limiting"}}'

# --- Scenes ---

clear

# Scene 1: Fresh session
draw_scene "$json_fresh" "" \
  "What does this codebase do?" \
  "Let me explore the project structure.|I can see this is a Go API gateway with..."
sleep 4

# Scene 2: Exploring with agent
draw_scene "$json_exploring" "" \
  "Find all the middleware and explain the request flow" \
  "${C_DIM}Using code-explorer agent...${C_RESET}||I found 6 middleware handlers in ${C_CYAN}internal/middleware/${C_RESET}:|  ${C_YELLOW}auth.go${C_RESET} -- JWT validation and session management|  ${C_YELLOW}ratelimit.go${C_RESET} -- Token bucket rate limiter|  ${C_YELLOW}cors.go${C_RESET} -- CORS header injection|  ${C_YELLOW}logging.go${C_RESET} -- Structured request/response logging"
sleep 4

# Scene 3: Implementing with Sonnet + worktree
draw_scene "$json_implementing" "" \
  "Add Redis-backed rate limiting to the /api/v2 endpoints" \
  "${C_DIM}Using feature-dev agent in worktree add-rate-limiting...${C_RESET}||I'll implement this in 3 parts:|| ${C_GREEN}1.${C_RESET} Redis connection pool in ${C_CYAN}internal/redis/pool.go${C_RESET}| ${C_GREEN}2.${C_RESET} Sliding window limiter in ${C_CYAN}internal/middleware/ratelimit_redis.go${C_RESET}| ${C_GREEN}3.${C_RESET} Route registration in ${C_CYAN}cmd/server/routes.go${C_RESET}"
sleep 4

# Scene 4: Code review
draw_scene "$json_reviewing" "" \
  "Review the implementation for issues" \
  "${C_DIM}Using code-reviewer agent...${C_RESET}||Found 2 issues:|| ${C_YELLOW}internal/redis/pool.go:47${C_RESET} -- Connection timeout should be configurable| ${C_YELLOW}internal/middleware/ratelimit_redis.go:83${C_RESET} -- Missing error handling on|   EVALSHA fallback"
sleep 4

# Scene 5: Critical context
draw_scene "$json_critical" "" \
  "Fix the issues and add tests" \
  "Fixed both issues. Added 12 tests covering:|| ${C_GREEN}PASS${C_RESET} TestRateLimiter_AllowsUnderLimit| ${C_GREEN}PASS${C_RESET} TestRateLimiter_BlocksOverLimit| ${C_GREEN}PASS${C_RESET} TestRateLimiter_SlidingWindow| ${C_GREEN}PASS${C_RESET} TestRateLimiter_RedisFailureFallback| ${C_GREEN}PASS${C_RESET} TestPool_ConfigurableTimeout| ${C_DIM}... and 7 more${C_RESET}"
sleep 4

# Scene 6: Dracula theme
draw_scene "$json_implementing" "dracula" \
  "Add Redis-backed rate limiting to the /api/v2 endpoints" \
  "${C_DIM}Using feature-dev agent in worktree add-rate-limiting...${C_RESET}||${C_GRAY}Theme: dracula${C_RESET}"
sleep 3

# Scene 7: Nord theme
draw_scene "$json_implementing" "nord" \
  "Add Redis-backed rate limiting to the /api/v2 endpoints" \
  "${C_DIM}Using feature-dev agent in worktree add-rate-limiting...${C_RESET}||${C_GRAY}Theme: nord${C_RESET}"
sleep 3

# Scene 8: Bluloco theme
draw_scene "$json_implementing" "bluloco-dark" \
  "Add Redis-backed rate limiting to the /api/v2 endpoints" \
  "${C_DIM}Using feature-dev agent in worktree add-rate-limiting...${C_RESET}||${C_GRAY}Theme: bluloco-dark${C_RESET}"
sleep 3
