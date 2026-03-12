#!/bin/sh
# lib.sh -- Rendering helpers, capability detection, platform utilities

# --- Capability detection ---
# Sets: SL_CAP_NERD, SL_CAP_UNICODE, SL_CAP_OSC8
# Also sets glyph variables based on capabilities
detect_capabilities() {
  # Nerd Font: env var override, default on
  SL_CAP_NERD="${CLAUDE_STATUSLINE_NERD_FONT:-1}"

  # Unicode: check locale
  case "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" in
    *[Uu][Tt][Ff]*) SL_CAP_UNICODE=1 ;;
    *)              SL_CAP_UNICODE=0 ;;
  esac

  # OSC 8 hyperlinks: disabled in tmux and SSH
  SL_CAP_OSC8=1
  [ -n "${TMUX:-}" ] && SL_CAP_OSC8=0
  [ -n "${SSH_CONNECTION:-}" ] && SL_CAP_OSC8=0

  # --- Set glyphs based on capabilities ---
  if [ "$SL_CAP_NERD" -eq 1 ]; then
    # Nerd Font glyphs (UTF-8 byte sequences)
    GL_POWERLINE='\xee\x82\xb0'        # U+E0B0
    GL_MODEL='\xef\x83\xab'            # U+F0EB nf-fa-lightbulb_o
    GL_CTX='\xef\x87\x80'              # U+F1C0 nf-fa-database
    GL_BURN='\xef\x83\xa4'             # U+F0E4 nf-fa-tachometer
    GL_CACHE='\xef\x80\x8a'            # U+F00A nf-fa-th
    GL_FOLDER='\xef\x81\xbc'           # U+F07C nf-fa-folder_open
    GL_BRANCH='\xee\x9c\xa5'           # U+E725 nf-dev-git_branch
    GL_DIRTY='\xef\x81\xaa'            # U+F06A nf-fa-exclamation_circle
    GL_DETACHED='\xef\x90\x97'         # U+F417 nf-oct-git_commit
    GL_CODE='\xef\x84\xa1'             # U+F121 nf-fa-code
    GL_WORKTREE='\xef\x83\xa8'         # U+F0E8 nf-fa-sitemap
    GL_CLOCK='\xef\x80\x97'            # U+F017 nf-fa-clock_o
    GL_WARN='\xef\x81\xb1'             # U+F071 nf-fa-warning
    GL_THIN_SEP='\xe2\x94\x82'         # U+2502
  else
    GL_POWERLINE='>'
    GL_MODEL=''
    GL_CTX='db'
    GL_BURN='rate'
    GL_CACHE=''
    GL_FOLDER='dir'
    GL_BRANCH='br'
    GL_DIRTY='!'
    GL_DETACHED='#'
    GL_CODE='code'
    GL_WORKTREE='wt'
    GL_CLOCK=''
    GL_WARN='!!'
    GL_THIN_SEP='|'
  fi

  # Unicode symbols (dots, arrows) -- independent of Nerd Font
  if [ "$SL_CAP_UNICODE" -eq 1 ]; then
    GL_DOT_FILLED='●'
    GL_DOT_EMPTY='○'
    GL_ARROW_UP='↗'
    GL_ARROW_DOWN='↘'
    GL_ARROW_FLAT='→'
  else
    GL_DOT_FILLED='*'
    GL_DOT_EMPTY='-'
    GL_ARROW_UP='+'
    GL_ARROW_DOWN='-'
    GL_ARROW_FLAT='='
  fi
}

# --- Platform detection ---
# Sets: SL_MD5_CMD, SL_STAT_FMT
detect_platform() {
  if command -v md5 >/dev/null 2>&1; then
    SL_MD5_CMD='md5 -q'
  else
    SL_MD5_CMD='md5sum'
  fi

  # macOS stat: stat -f %m <file> returns mtime as epoch
  # Linux stat: stat -c %Y <file> returns mtime as epoch
  if stat -f %m /dev/null >/dev/null 2>&1; then
    SL_STAT_FMT='stat -f %m'
  else
    SL_STAT_FMT='stat -c %Y'
  fi
}

# --- Row buffer management ---
# Each row builds into sl_row via emit_segment/emit_thin_sep/emit_end
sl_row=""
sl_prev_bg=""

reset_row() {
  sl_row=""
  sl_prev_bg=""
}

# --- emit_segment(bg_num, fg_num, content) ---
# Appends a segment with powerline transition from previous segment
emit_segment() {
  _es_bg="$1"
  _es_fg="$2"
  _es_content="$3"

  _es_bg_esc="\033[48;5;${_es_bg}m"
  _es_fg_esc="\033[38;5;${_es_fg}m"

  if [ -z "$sl_prev_bg" ]; then
    # First segment: just set BG+FG
    sl_row="${sl_row}${_es_bg_esc}${_es_fg_esc}${_es_content}"
  elif [ "$sl_prev_bg" = "$_es_bg" ]; then
    # Same BG: just change FG (no separator)
    sl_row="${sl_row}${_es_fg_esc}${_es_content}"
  else
    # Different BG: powerline arrow transition
    sl_row="${sl_row}${RST}\033[38;5;${sl_prev_bg}m${_es_bg_esc}${GL_POWERLINE}${_es_fg_esc}${_es_content}"
  fi

  sl_prev_bg="$_es_bg"
}

# --- emit_thin_sep() ---
# Outputs thin separator in dim FG on current BG
emit_thin_sep() {
  if [ -n "$sl_prev_bg" ]; then
    sl_row="${sl_row}\033[38;5;${C_DIM}m${GL_THIN_SEP}"
  fi
}

# --- emit_end() ---
# Closes the row with a trailing powerline arrow
emit_end() {
  if [ -n "$sl_prev_bg" ]; then
    sl_row="${sl_row}${RST}\033[38;5;${sl_prev_bg}m${GL_POWERLINE}${RST}"
  fi
}

# --- osc8_link(url, text) ---
# Wraps text in OSC 8 hyperlink if supported, otherwise plain text
osc8_link() {
  _ol_url="$1"
  _ol_text="$2"
  if [ "$SL_CAP_OSC8" -eq 1 ] && [ -n "$_ol_url" ]; then
    printf '\033]8;;%s\a%s\033]8;;\a' "$_ol_url" "$_ol_text"
  else
    printf '%s' "$_ol_text"
  fi
}

# --- format_tokens(varname, count) ---
# Sets varname to formatted token count: raw <1000, Xk for 1000+, X.Xm for 1M+
format_tokens() {
  _ft_n="$2"
  if [ "$_ft_n" -ge 1000000 ] 2>/dev/null; then
    _ft_m=$(( _ft_n / 100000 ))
    _ft_val="$(( _ft_m / 10 )).$(( _ft_m % 10 ))m"
  elif [ "$_ft_n" -ge 1000 ] 2>/dev/null; then
    _ft_val="$(( _ft_n / 1000 ))k"
  else
    _ft_val="$_ft_n"
  fi
  eval "$1"'="$_ft_val"'
}

# --- emit_on_muted(fg_num, content) ---
# Emits content on muted BG, using thin sep if already on muted, else powerline
emit_on_muted() {
  _eom_fg="$1"
  _eom_content="$2"
  if [ "$sl_prev_bg" = "$C_MUTED_BG" ]; then
    emit_thin_sep
    sl_row="${sl_row}\033[38;5;${_eom_fg}m${_eom_content}"
  else
    emit_segment "$C_MUTED_BG" "$_eom_fg" "$_eom_content"
  fi
}

# --- emit_recessed(fg_num, content) ---
# Emits content on dim BG. Uses thin sep from muted BG (subtle transition).
emit_recessed() {
  _er_fg="$1"
  _er_content="$2"
  if [ "$sl_prev_bg" = "$C_DIM_BG" ]; then
    emit_thin_sep
    sl_row="${sl_row}\033[38;5;${_er_fg}m${_er_content}"
  else
    emit_thin_sep
    sl_row="${sl_row}\033[48;5;${C_DIM_BG}m\033[38;5;${_er_fg}m${_er_content}"
    sl_prev_bg="$C_DIM_BG"
  fi
}

# --- render_row(group) ---
# Iterates SL_SEGMENTS, calls each function, applies tier/group gates,
# emits based on weight classification.
render_row() {
  _rr_group="$1"

  for _seg_fn in $SL_SEGMENTS; do
    # Reset segment metadata
    _seg_weight="" ; _seg_min_tier="" ; _seg_group=""
    _seg_content="" ; _seg_icon="" ; _seg_bg="" ; _seg_fg=""
    _seg_attrs="" ; _seg_detail="" ; _seg_link_url=""

    # Call segment function -- skip if returns non-zero
    "$_seg_fn" || continue

    # Tier gate
    case "$_seg_min_tier" in
      full)    [ "$_sl_tier" != "full" ] && continue ;;
      compact) [ "$_sl_tier" = "micro" ] && continue ;;
      micro)   ;;
    esac

    # Group gate (full tier only)
    if [ "$_sl_tier" = "full" ] && [ -n "$_rr_group" ] && [ "$_seg_group" != "$_rr_group" ]; then
      continue
    fi

    # Icon handling (no icons in micro tier)
    _rr_icon=""
    if [ "$SL_CAP_NERD" -eq 1 ] && [ -n "$_seg_icon" ] && [ "$_sl_tier" != "micro" ]; then
      _rr_icon="${_seg_icon} "
    fi

    # OSC 8 link wrapping (orchestrator applies, not segments)
    if [ "$SL_CAP_OSC8" -eq 1 ] && [ -n "$_seg_link_url" ]; then
      _seg_content=$(printf '\033]8;;%s\a%s\033]8;;\a' "$_seg_link_url" "$_seg_content")
    fi

    # Attribute handling (bold, blink)
    _rr_attr_start=""
    _rr_attr_end=""
    if [ -n "$_seg_attrs" ]; then
      case " $_seg_attrs " in
        *" bold "*) _rr_attr_start="${_rr_attr_start}${SL_BOLD}" ;;
      esac
      case " $_seg_attrs " in
        *" blink "*) _rr_attr_start="${_rr_attr_start}${SL_BLINK}" ;;
      esac
    fi

    # Determine effective BG/FG for attr reset
    # Tertiary default is C_DIM, but segments can override _seg_fg for custom color
    case "$_seg_weight" in
      primary)
        _rr_ebg="$_seg_bg"; _rr_efg="$_seg_fg"
        ;;
      secondary)
        _rr_ebg="$C_MUTED_BG"; _rr_efg="$C_BASE_FG"
        ;;
      tertiary)
        _rr_ebg="$C_MUTED_BG"
        _rr_efg="${_seg_fg:-$C_DIM}"
        ;;
      recessed)
        _rr_ebg="$C_DIM_BG"; _rr_efg="${_seg_fg:-$C_DIM}"
        ;;
    esac

    # Build attr end sequence if attrs were set
    if [ -n "$_rr_attr_start" ]; then
      _rr_attr_end="${RST}\033[48;5;${_rr_ebg}m\033[38;5;${_rr_efg}m"
    fi

    # Build detail suffix (dim inline text for secondary info like ahead/behind)
    _rr_detail=""
    if [ -n "$_seg_detail" ]; then
      _rr_detail=" ${SL_DIM}\033[38;5;${C_DIM}m${_seg_detail}${SL_UNDIM}\033[38;5;${_rr_efg}m"
    fi

    # Build padded content
    _rr_text=" ${_rr_attr_start}${_rr_icon}${_seg_content}${_rr_detail}${_rr_attr_end} "

    # Emit based on weight
    case "$_seg_weight" in
      primary)    emit_segment "$_seg_bg" "$_seg_fg" "$_rr_text" ;;
      secondary)  emit_on_muted "$C_BASE_FG" "$_rr_text" ;;
      tertiary)   emit_on_muted "$_rr_efg" "$_rr_text" ;;
      recessed)   emit_recessed "$_rr_efg" "$_rr_text" ;;
    esac
  done

  emit_end
}
