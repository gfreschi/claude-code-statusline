#!/bin/sh
# install.sh -- Install, update, or uninstall claude-code-statusline
# Usage:
#   sh install.sh [install|update|uninstall] [--force]
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/.../install.sh)"
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/.../install.sh)" _ --force

set -e

REPO_URL="https://github.com/gfreschi/claude-code-statusline.git"
INSTALL_DIR="${CLAUDE_STATUSLINE_DIR:-$HOME/.claude/statusline}"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_CMD="sh $INSTALL_DIR/main.sh"

# --- Helpers ---

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

check_deps() {
  command -v git >/dev/null 2>&1 || die "git is required but not found"
  command -v jq >/dev/null 2>&1 || die "jq is required but not found (https://jqlang.github.io/jq/)"
}

confirm() {
  printf '%s [y/N] ' "$1"
  read -r _cf_reply
  case "$_cf_reply" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

# --- Install ---

do_install() {
  check_deps

  if [ -d "$INSTALL_DIR" ]; then
    if [ "$_is_force" -eq 1 ]; then
      echo "Removing existing installation at $INSTALL_DIR"
      rm -rf "$INSTALL_DIR"
    else
      die "Already installed at $INSTALL_DIR. Run 'sh install.sh update' to update, or use --force to reinstall."
    fi
  fi

  echo "Cloning to $INSTALL_DIR..."
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"

  # Patch settings.json
  if [ ! -f "$SETTINGS_FILE" ]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    printf '{\n  "statusLine": "%s"\n}\n' "$STATUSLINE_CMD" > "$SETTINGS_FILE"
    echo "Created $SETTINGS_FILE"
  else
    _di_current=$(jq -r '.statusLine // empty' "$SETTINGS_FILE" 2>/dev/null)
    if [ -z "$_di_current" ]; then
      # No statusLine key -- add it
      _di_tmp="${SETTINGS_FILE}.tmp.$$"
      jq --arg cmd "$STATUSLINE_CMD" '. + {statusLine: $cmd}' "$SETTINGS_FILE" > "$_di_tmp"
      mv "$_di_tmp" "$SETTINGS_FILE"
      echo "Added statusLine to $SETTINGS_FILE"
    elif [ "$_di_current" = "$STATUSLINE_CMD" ]; then
      echo "Settings already configured"
    else
      echo "Current statusLine: $_di_current"
      if [ "$_is_force" -eq 1 ] || confirm "Replace with '$STATUSLINE_CMD'?"; then
        _di_tmp="${SETTINGS_FILE}.tmp.$$"
        jq --arg cmd "$STATUSLINE_CMD" '.statusLine = $cmd' "$SETTINGS_FILE" > "$_di_tmp"
        mv "$_di_tmp" "$SETTINGS_FILE"
        echo "Updated statusLine in $SETTINGS_FILE"
      else
        echo "Skipped settings update"
      fi
    fi
  fi

  echo ""
  echo "Installed successfully. Restart Claude Code to activate the status line."
}

# --- Update ---

do_update() {
  [ -d "$INSTALL_DIR" ] || die "Not installed at $INSTALL_DIR. Run 'sh install.sh install' first."
  [ -d "$INSTALL_DIR/.git" ] || die "$INSTALL_DIR is not a git repository"

  echo "Updating..."
  if git -C "$INSTALL_DIR" pull --ff-only --quiet 2>/dev/null; then
    _du_hash=$(git -C "$INSTALL_DIR" rev-parse --short HEAD)
    _du_date=$(git -C "$INSTALL_DIR" log -1 --format=%cs)
    echo "Updated to ${_du_hash} (${_du_date}). Restart Claude Code to apply changes."
  else
    die "Update failed (local changes or diverged history). Resolve manually: cd $INSTALL_DIR && git status"
  fi
}

# --- Uninstall ---

do_uninstall() {
  if [ -f "$SETTINGS_FILE" ]; then
    _ui_has_key=$(jq 'has("statusLine")' "$SETTINGS_FILE" 2>/dev/null)
    if [ "$_ui_has_key" = "true" ]; then
      _ui_tmp="${SETTINGS_FILE}.tmp.$$"
      jq 'del(.statusLine)' "$SETTINGS_FILE" > "$_ui_tmp"
      mv "$_ui_tmp" "$SETTINGS_FILE"
      echo "Removed statusLine from $SETTINGS_FILE"
    fi
  fi

  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
  fi

  echo "Uninstalled. Restart Claude Code to apply."
}

# --- Main ---

_is_force=0
_is_cmd=""

for _arg in "$@"; do
  case "$_arg" in
    --force) _is_force=1 ;;
    install|update|uninstall) _is_cmd="$_arg" ;;
    *)
      echo "Usage: sh install.sh [install|update|uninstall] [--force]" >&2
      exit 1
      ;;
  esac
done

# Default to install when no subcommand (curl | sh pattern)
_is_cmd="${_is_cmd:-install}"

case "$_is_cmd" in
  install)   do_install ;;
  update)    do_update ;;
  uninstall) do_uninstall ;;
esac
