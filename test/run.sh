#!/bin/sh
# test/run.sh -- Test harness for claude-code-statusline
# Usage:
#   sh test/run.sh                              # visual: all scenarios, default theme
#   sh test/run.sh --scenario full              # visual: one scenario
#   sh test/run.sh --scenario full --theme nord # visual: one scenario, specific theme
#   sh test/run.sh --check                      # CI: assert all combinations, exit 0/1
#   sh test/run.sh --check --shell dash         # CI: run main.sh under specific shell

DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$DIR/.." && pwd)"

# Bundled themes and scenarios for iteration
ALL_THEMES="catppuccin-mocha bluloco-dark dracula nord"
ALL_SCENARIOS="minimal mid full critical"
TIERS="full compact micro"
TIER_COLS_full=140
TIER_COLS_compact=100
TIER_COLS_micro=60

# Defaults
_tr_mode="visual"
_tr_scenario=""
_tr_theme=""
_tr_shell="sh"

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --check)    _tr_mode="check"; shift ;;
    --scenario) _tr_scenario="$2"; shift 2 ;;
    --theme)    _tr_theme="$2"; shift 2 ;;
    --shell)    _tr_shell="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: sh test/run.sh [--check] [--scenario NAME] [--theme NAME] [--shell CMD]" >&2
      exit 1
      ;;
  esac
done

# --- Visual mode ---
run_visual() {
  _rv_scenarios="${_tr_scenario:-$ALL_SCENARIOS}"
  _rv_theme="${_tr_theme:-catppuccin-mocha}"

  for _rv_scn in $_rv_scenarios; do
    _rv_fixture="$DIR/fixtures/${_rv_scn}.json"
    if [ ! -f "$_rv_fixture" ]; then
      echo "Unknown scenario: $_rv_scn (no fixture at $_rv_fixture)" >&2
      exit 1
    fi
    _rv_json=$(cat "$_rv_fixture")

    echo "=== Scenario: $_rv_scn | Theme: $_rv_theme ==="
    echo ""

    for _rv_tier in $TIERS; do
      eval "_rv_cols=\$TIER_COLS_${_rv_tier}"
      echo "--- ${_rv_tier} tier (COLUMNS=${_rv_cols}) ---"
      echo "$_rv_json" | COLUMNS="$_rv_cols" CLAUDE_STATUSLINE_THEME="$_rv_theme" "$_tr_shell" "$PROJECT_ROOT/main.sh"
      echo ""
    done
  done
}

# --- Check mode ---
run_check() {
  _rc_pass=0
  _rc_fail=0
  _rc_total=0

  _rc_scenarios="${_tr_scenario:-$ALL_SCENARIOS}"
  _rc_themes="${_tr_theme:-$ALL_THEMES}"

  for _rc_theme in $_rc_themes; do
    for _rc_scn in $_rc_scenarios; do
      _rc_fixture="$DIR/fixtures/${_rc_scn}.json"
      if [ ! -f "$_rc_fixture" ]; then
        echo "FAIL: unknown scenario $_rc_scn" >&2
        _rc_fail=$(( _rc_fail + 1 ))
        _rc_total=$(( _rc_total + 1 ))
        continue
      fi
      _rc_json=$(cat "$_rc_fixture")

      for _rc_tier in $TIERS; do
        eval "_rc_cols=\$TIER_COLS_${_rc_tier}"
        _rc_total=$(( _rc_total + 1 ))
        _rc_label="${_rc_theme}/${_rc_scn}/${_rc_tier}"

        # Run main.sh and capture output + exit code
        _rc_output=$(echo "$_rc_json" | COLUMNS="$_rc_cols" CLAUDE_STATUSLINE_THEME="$_rc_theme" "$_tr_shell" "$PROJECT_ROOT/main.sh" 2>&1)
        _rc_exit=$?

        # Assert: exit code 0
        if [ "$_rc_exit" -ne 0 ]; then
          echo "FAIL [$_rc_label]: exit code $_rc_exit"
          _rc_fail=$(( _rc_fail + 1 ))
          continue
        fi

        # Assert: output is non-empty
        if [ -z "$_rc_output" ]; then
          echo "FAIL [$_rc_label]: empty output"
          _rc_fail=$(( _rc_fail + 1 ))
          continue
        fi

        # Assert: no raw _seg_ variable leaks (assignment form)
        case "$_rc_output" in
          *_seg_weight=*|*_seg_content=*|*_seg_bg=*|*_seg_fg=*|*_seg_icon=*)
            echo "FAIL [$_rc_label]: _seg_ variable leak in output"
            _rc_fail=$(( _rc_fail + 1 ))
            continue
            ;;
        esac

        echo "PASS [$_rc_label]"
        _rc_pass=$(( _rc_pass + 1 ))
      done
    done
  done

  echo ""
  echo "Results: $_rc_pass passed, $_rc_fail failed, $_rc_total total"

  [ "$_rc_fail" -eq 0 ]
}

# --- Main ---
case "$_tr_mode" in
  visual) run_visual ;;
  check)  run_check ;;
esac
