#!/bin/sh
# render.sh -- Rendering helpers, capability detection, platform utilities

# Zsh invokes this file without honoring the #!/bin/sh shebang (it's run
# inside the caller's zsh process when sourced, or as a zsh script when
# the test harness does `zsh main.sh`). Zsh's default is to NOT word-split
# unquoted parameter expansions, which breaks our `for x in $LIST` loops.
# Enable POSIX word splitting so the same code path runs identically
# under sh / dash / bash / zsh.
[ -n "${ZSH_VERSION:-}" ] && setopt SH_WORD_SPLIT 2>/dev/null

# --- to_int(varname, value, default) ---
# Parses $value as an integer into $varname, or uses $default on failure.
# Handles empty strings, floats (truncates at '.'), and non-numeric input
# safely under dash -- which aborts the shell on `$(( "52.5" + 0 ))` even
# when the expression is guarded by `2>/dev/null || ...`.
to_int() {
  _ti_val="$2"
  # Floor floats by stripping the fractional tail.
  case "$_ti_val" in *.*) _ti_val="${_ti_val%%.*}" ;; esac
  case "$_ti_val" in
    ''|*[!0-9-]*|-*[!0-9]*) eval "$1=\$3" ;;
    *) eval "$1=\$_ti_val" ;;
  esac
}

# --- sl_truncate(varname, text, max_len) ---
# If `text` is longer than max_len chars, writes `prefix + GL_ELLIPSIS` to
# varname, where prefix is the first max_len-1 characters. Otherwise writes
# text unchanged.
#
# Note: ${#STRING} counts bytes, not display columns, under POSIX sh. We
# only call this on Latin-1-clean inputs (branch names, agent names,
# project paths) so byte count and column count agree. GL_ELLIPSIS is
# counted as one column even in ASCII fallback (`..`, 2 chars); the tiny
# overflow in non-unicode terminals is acceptable.
sl_truncate() {
  _tr_var="$1"
  _tr_text="$2"
  _tr_max="$3"
  if [ "${#_tr_text}" -gt "$_tr_max" ]; then
    _tr_cut=$(( _tr_max - 1 ))
    _tr_text="$(printf '%.'"${_tr_cut}"'s' "$_tr_text")${GL_ELLIPSIS}"
  fi
  eval "$_tr_var=\$_tr_text"
}

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

  # Cap shape selection (capsule vs. powerline triangle)
  case "${CLAUDE_STATUSLINE_CAP_STYLE:-powerline}" in
    capsule) SL_USE_CAPSULE=1 ;;
    *)       SL_USE_CAPSULE=0 ;;
  esac

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
    GL_BATT_FULL='\xef\x89\x80'        # U+F240 nf-fa-battery_full
    GL_BATT_MID='\xef\x89\x82'         # U+F242 nf-fa-battery_half
    GL_BATT_LOW='\xef\x89\x84'         # U+F244 nf-fa-battery_quarter
    GL_FORK='\xef\x90\x82'             # U+F402 nf-oct-repo_forked
    GL_CAP_LEFT='\xee\x82\xb6'         # U+E0B6 powerline round left
    GL_CAP_RIGHT='\xee\x82\xb4'        # U+E0B4 powerline round right
    GL_UP='\xe2\x86\x91'               # U+2191
    GL_DOWN='\xe2\x86\x93'             # U+2193
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
    GL_BATT_FULL='FULL'
    GL_BATT_MID='MID'
    GL_BATT_LOW='LOW'
    GL_FORK='fork'
    GL_CAP_LEFT='('
    GL_CAP_RIGHT=')'
    GL_UP='^'
    GL_DOWN='v'
  fi

  # Unicode symbols (dots, arrows) -- independent of Nerd Font
  if [ "$SL_CAP_UNICODE" -eq 1 ]; then
    GL_DOT_FILLED='●'
    GL_DOT_EMPTY='○'
    GL_ARROW_UP='↗'
    GL_ARROW_DOWN='↘'
    GL_ARROW_FLAT='→'
    GL_SEP='·'                         # U+00B7 middle dot (ornamental)
    GL_ELLIPSIS='…'                    # U+2026 horizontal ellipsis
    GL_BLK_FILLED='\xe2\x96\x93'       # U+2593
    GL_BLK_EMPTY='\xe2\x96\x91'        # U+2591
    GL_PIP_FILLED='\xc2\xb7'           # U+00B7 middle dot
    GL_PIP_EMPTY=' '
    GL_BRL_0='\xe2\xa0\x80'            # U+2800
    GL_BRL_1='\xe2\xa0\x81'            # U+2801
    GL_BRL_2='\xe2\xa0\x83'            # U+2803
    GL_BRL_3='\xe2\xa0\x87'            # U+2807
    GL_BRL_4='\xe2\xa0\x8f'            # U+280F
    GL_BRL_5='\xe2\xa0\x9f'            # U+281F
    GL_BRL_6='\xe2\xa0\xbf'            # U+283F
    GL_BRL_7='\xe2\xa1\xbf'            # U+287F
    GL_BRL_8='\xe2\xa3\xbf'            # U+28FF
  else
    GL_DOT_FILLED='*'
    GL_DOT_EMPTY='-'
    GL_ARROW_UP='+'
    GL_ARROW_DOWN='-'
    GL_ARROW_FLAT='='
    GL_SEP='.'                         # ASCII fallback
    GL_ELLIPSIS='..'                   # ASCII fallback
    GL_BLK_FILLED='#'
    GL_BLK_EMPTY='.'
    GL_PIP_FILLED='*'
    GL_PIP_EMPTY=' '
    GL_BRL_0='_'
    GL_BRL_1='_'
    GL_BRL_2='.'
    GL_BRL_3='.'
    GL_BRL_4='-'
    GL_BRL_5='-'
    GL_BRL_6='='
    GL_BRL_7='+'
    GL_BRL_8='#'
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
    # First segment on this row. Capsule style prepends a left-cap glyph
    # in the upcoming segment's BG color on the terminal's default BG.
    if [ "${SL_USE_CAPSULE:-0}" -eq 1 ]; then
      sl_row="${sl_row}${SL_RST}\033[38;5;${_es_bg}m${GL_CAP_LEFT}${_es_bg_esc}${_es_fg_esc}${_es_content}"
    else
      sl_row="${sl_row}${_es_bg_esc}${_es_fg_esc}${_es_content}"
    fi
  elif [ "$sl_prev_bg" = "$_es_bg" ]; then
    # Same BG: just change FG (no separator)
    sl_row="${sl_row}${_es_fg_esc}${_es_content}"
  else
    # Different BG: powerline arrow transition
    sl_row="${sl_row}${SL_RST}\033[38;5;${sl_prev_bg}m${_es_bg_esc}${GL_POWERLINE}${_es_fg_esc}${_es_content}"
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
# Closes the row with a trailing cap (powerline arrow or capsule right-cap)
emit_end() {
  if [ -n "$sl_prev_bg" ]; then
    if [ "${SL_USE_CAPSULE:-0}" -eq 1 ]; then
      sl_row="${sl_row}${SL_RST}\033[38;5;${sl_prev_bg}m${GL_CAP_RIGHT}${SL_RST}"
    else
      sl_row="${sl_row}${SL_RST}\033[38;5;${sl_prev_bg}m${GL_POWERLINE}${SL_RST}"
    fi
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

# --- ctx_gauge_render(output_var, pct) ---
# Produces a 5-cell gauge based on CLAUDE_STATUSLINE_CTX_GAUGE env var.
# Supported styles: dots (default), blocks, pips, braille.
ctx_gauge_render() {
  _cg_out_var="$1"
  to_int _cg_pct "${2:-0}" 0
  [ "$_cg_pct" -lt 0 ] && _cg_pct=0
  [ "$_cg_pct" -gt 100 ] && _cg_pct=100
  _cg_filled=$(( _cg_pct / 20 ))
  [ "$_cg_filled" -gt 5 ] && _cg_filled=5
  _cg_empty=$(( 5 - _cg_filled ))
  _cg_result=""
  case "${CLAUDE_STATUSLINE_CTX_GAUGE:-dots}" in
    blocks)
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_filled" ]; do _cg_result="${_cg_result}${GL_BLK_FILLED}"; _cg_i=$((_cg_i+1)); done
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_empty"  ]; do _cg_result="${_cg_result}${GL_BLK_EMPTY}";  _cg_i=$((_cg_i+1)); done
      ;;
    pips)
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_filled" ]; do _cg_result="${_cg_result}${GL_PIP_FILLED} "; _cg_i=$((_cg_i+1)); done
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_empty"  ]; do _cg_result="${_cg_result}${GL_PIP_EMPTY} ";  _cg_i=$((_cg_i+1)); done
      _cg_result="${_cg_result% }"
      ;;
    braille)
      # Map pct into 9 buckets (BRL_0..BRL_8) stretched across 3 cells
      _cg_n=$(( _cg_pct * 9 / 100 ))
      [ "$_cg_n" -gt 8 ] && _cg_n=8
      eval "_cg_result=\$GL_BRL_${_cg_n}\$GL_BRL_${_cg_n}\$GL_BRL_${_cg_n}"
      ;;
    dots|*)
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_filled" ]; do _cg_result="${_cg_result}${GL_DOT_FILLED}"; _cg_i=$((_cg_i+1)); done
      _cg_i=0; while [ "$_cg_i" -lt "$_cg_empty"  ]; do _cg_result="${_cg_result}${GL_DOT_EMPTY}";  _cg_i=$((_cg_i+1)); done
      ;;
  esac
  eval "$_cg_out_var=\$_cg_result"
}

# --- render_row(group) ---
# Iterates SL_SEGMENTS, calls each function, applies tier/group gates,
# emits based on weight classification.
render_row() {
  _rr_group="$1"
  _rr_minimal="${CLAUDE_STATUSLINE_MINIMAL:-0}"

  for _seg_fn in $SL_SEGMENTS; do
    # Reset segment metadata
    _seg_weight="" ; _seg_min_tier="" ; _seg_group=""
    _seg_group_fallback=""
    _seg_content="" ; _seg_icon="" ; _seg_bg="" ; _seg_fg=""
    _seg_attrs="" ; _seg_detail="" ; _seg_link_url=""

    # Call segment function -- skip if returns non-zero
    "$_seg_fn" || continue

    # Tier gate. Hierarchy: zen > full > compact > micro. A segment declares
    # the minimum tier it renders in; higher tiers inherit.
    case "$_seg_min_tier" in
      zen)     [ "$_sl_tier" != "zen" ] && continue ;;
      full)    [ "$_sl_tier" != "zen" ] && [ "$_sl_tier" != "full" ] && continue ;;
      compact) [ "$_sl_tier" = "micro" ] && continue ;;
      micro)   ;;
    esac

    # Group + fallback resolution
    _rr_eff_group="$_seg_group"
    if [ "$_sl_layout" != "zen" ] && [ -n "$_seg_group_fallback" ]; then
      _rr_eff_group="$_seg_group_fallback"
    fi

    # Ambient group hard-enforces recessed weight (contract C3)
    if [ "$_seg_group" = "ambient" ] && [ "$_seg_weight" != "recessed" ]; then
      _seg_weight="recessed"
    fi

    # Group gate (multi-row tiers only)
    if [ "$_sl_tier" = "full" ] || [ "$_sl_tier" = "zen" ]; then
      if [ -n "$_rr_group" ] && [ "$_rr_eff_group" != "$_rr_group" ]; then
        continue
      fi
    fi

    # Icon handling (no icons in micro tier, skipped entirely in minimal mode)
    _rr_icon=""
    if [ "$_rr_minimal" != "1" ] && [ "$SL_CAP_NERD" -eq 1 ] && [ -n "$_seg_icon" ] && [ "$_sl_tier" != "micro" ]; then
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
      _rr_attr_end="${SL_RST}\033[48;5;${_rr_ebg}m\033[38;5;${_rr_efg}m"
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
