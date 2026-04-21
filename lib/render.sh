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
  # Reject empty, non-numeric, bare "-", "-foo", and any embedded dash
  # ("5-6", "1-2-3") so arithmetic never sees a malformed integer.
  case "$_ti_val" in
    ''|-|*[!0-9-]*|-*[!0-9]*|*-*-*|*[0-9]-*) eval "$1=\$3" ;;
    *) eval "$1=\$_ti_val" ;;
  esac
}

# --- sl_truncate(varname, text, max_len) ---
# If `text` is longer than max_len bytes, writes `prefix + GL_ELLIPSIS` to
# varname, where prefix is the first max_len-1 bytes. Otherwise writes
# text unchanged.
#
# Caveats:
#   - ${#STRING} counts bytes, not codepoints, under dash / POSIX sh.
#     Multi-byte UTF-8 labels (e.g. a branch name with accents) can be
#     cut mid-codepoint, leaving a replacement-char tail. The call sites
#     all accept user-supplied labels, and a stray U+FFFD at the end is
#     visually no worse than no-truncation overflow.
#   - GL_ELLIPSIS is counted as one column even in ASCII fallback
#     (`..`, 2 bytes); ASCII-fallback output may overrun max_len by 1.
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
    GL_POWERLINE='\0356\0202\0260'        # U+E0B0
    GL_MODEL='\0357\0203\0253'            # U+F0EB nf-fa-lightbulb_o
    GL_CTX='\0357\0207\0200'              # U+F1C0 nf-fa-database
    GL_BURN='\0357\0203\0244'             # U+F0E4 nf-fa-tachometer
    GL_CACHE='\0357\0200\0212'            # U+F00A nf-fa-th
    GL_FOLDER='\0357\0201\0274'           # U+F07C nf-fa-folder_open
    GL_BRANCH='\0356\0234\0245'           # U+E725 nf-dev-git_branch
    GL_DIRTY='\0357\0201\0252'            # U+F06A nf-fa-exclamation_circle
    GL_DETACHED='\0357\0220\0227'         # U+F417 nf-oct-git_commit
    GL_CODE='\0357\0204\0241'             # U+F121 nf-fa-code
    GL_WORKTREE='\0357\0203\0250'         # U+F0E8 nf-fa-sitemap
    GL_CLOCK='\0357\0200\0227'            # U+F017 nf-fa-clock_o
    GL_WARN='\0357\0201\0261'             # U+F071 nf-fa-warning
    GL_THIN_SEP='\0342\0224\0202'         # U+2502
    GL_BATT_FULL='\0357\0211\0200'        # U+F240 nf-fa-battery_full
    GL_BATT_MID='\0357\0211\0202'         # U+F242 nf-fa-battery_half
    GL_BATT_LOW='\0357\0211\0204'         # U+F244 nf-fa-battery_quarter
    GL_FORK='\0357\0220\0202'             # U+F402 nf-oct-repo_forked
    GL_CAP_LEFT='\0356\0202\0266'         # U+E0B6 powerline round left
    GL_CAP_RIGHT='\0356\0202\0264'        # U+E0B4 powerline round right
    GL_UP='\0342\0206\0221'               # U+2191
    GL_DOWN='\0342\0206\0223'             # U+2193
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
    GL_BLK_FILLED='\0342\0226\0223'       # U+2593
    GL_BLK_EMPTY='\0342\0226\0221'        # U+2591
    GL_PIP_FILLED='\0302\0267'           # U+00B7 middle dot
    GL_PIP_EMPTY=' '
    GL_BRL_0='\0342\0240\0200'            # U+2800
    GL_BRL_1='\0342\0240\0201'            # U+2801
    GL_BRL_2='\0342\0240\0203'            # U+2803
    GL_BRL_3='\0342\0240\0207'            # U+2807
    GL_BRL_4='\0342\0240\0217'            # U+280F
    GL_BRL_5='\0342\0240\0237'            # U+281F
    GL_BRL_6='\0342\0240\0277'            # U+283F
    GL_BRL_7='\0342\0241\0277'            # U+287F
    GL_BRL_8='\0342\0243\0277'            # U+28FF
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

  _es_bg_esc="\0033[48;5;${_es_bg}m"
  _es_fg_esc="\0033[38;5;${_es_fg}m"

  if [ -z "$sl_prev_bg" ]; then
    # First segment on this row. Capsule style prepends a left-cap glyph
    # in the upcoming segment's BG color on the terminal's default BG.
    if [ "${SL_USE_CAPSULE:-0}" -eq 1 ]; then
      sl_row="${sl_row}${SL_RST}\0033[38;5;${_es_bg}m${GL_CAP_LEFT}${_es_bg_esc}${_es_fg_esc}${_es_content}"
    else
      sl_row="${sl_row}${_es_bg_esc}${_es_fg_esc}${_es_content}"
    fi
  elif [ "$sl_prev_bg" = "$_es_bg" ]; then
    # Same BG: no powerline transition, but reset any stray attrs from the
    # prior segment (bold/blink left over if the attr_end SGR on the
    # previous segment underflowed) and reapply BG+FG before the content.
    sl_row="${sl_row}${SL_RST}${_es_bg_esc}${_es_fg_esc}${_es_content}"
  else
    # Different BG: powerline arrow transition
    sl_row="${sl_row}${SL_RST}\0033[38;5;${sl_prev_bg}m${_es_bg_esc}${GL_POWERLINE}${_es_fg_esc}${_es_content}"
  fi

  sl_prev_bg="$_es_bg"
}

# --- emit_thin_sep() ---
# Outputs thin separator in dim FG on current BG
emit_thin_sep() {
  if [ -n "$sl_prev_bg" ]; then
    sl_row="${sl_row}\0033[38;5;${C_DIM}m${GL_THIN_SEP}"
  fi
}

# --- emit_end() ---
# Closes the row with a trailing cap (powerline arrow or capsule right-cap)
emit_end() {
  if [ -n "$sl_prev_bg" ]; then
    if [ "${SL_USE_CAPSULE:-0}" -eq 1 ]; then
      sl_row="${sl_row}${SL_RST}\0033[38;5;${sl_prev_bg}m${GL_CAP_RIGHT}${SL_RST}"
    else
      sl_row="${sl_row}${SL_RST}\0033[38;5;${sl_prev_bg}m${GL_POWERLINE}${SL_RST}"
    fi
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
    # Full reset + re-apply BG/FG before the content so bold/blink from a
    # prior same-BG segment does not linger into this one.
    sl_row="${sl_row}${SL_RST}\0033[48;5;${C_MUTED_BG}m\0033[38;5;${_eom_fg}m${_eom_content}"
  else
    emit_segment "$C_MUTED_BG" "$_eom_fg" "$_eom_content"
  fi
}

# --- emit_recessed(fg_num, content) ---
# Emits content on dim BG. Uses thin sep from muted BG (subtle transition).
emit_recessed() {
  _er_fg="$1"
  _er_content="$2"
  # First emitter on the row: delegate to emit_segment so the capsule
  # left-cap glyph gets rendered (when CAP_STYLE=capsule). Otherwise the
  # row would open with no left cap on rows that happen to start with a
  # recessed segment.
  if [ -z "$sl_prev_bg" ]; then
    emit_segment "$C_DIM_BG" "$_er_fg" "$_er_content"
    return
  fi
  if [ "$sl_prev_bg" = "$C_DIM_BG" ]; then
    emit_thin_sep
    sl_row="${sl_row}${SL_RST}\0033[48;5;${C_DIM_BG}m\0033[38;5;${_er_fg}m${_er_content}"
  else
    emit_thin_sep
    sl_row="${sl_row}${SL_RST}\0033[48;5;${C_DIM_BG}m\0033[38;5;${_er_fg}m${_er_content}"
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
      # Map pct into 9 buckets (BRL_0..BRL_8) stretched across 3 cells.
      # Rounded division so pct=95 maps to bucket 8 (full) instead of
      # saturating at pct>=89 as the truncating 9/100 mapping did.
      _cg_n=$(( (_cg_pct * 8 + 50) / 100 ))
      [ "$_cg_n" -gt 8 ] && _cg_n=8
      [ "$_cg_n" -lt 0 ] && _cg_n=0
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

    # Defensive default: a segment that forgets to set _seg_weight would
    # otherwise fall through the weight case below and be silently dropped.
    # Tertiary is the least-committal non-primary choice.
    [ -z "$_seg_weight" ] && _seg_weight="tertiary"

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

    # OSC 8 link wrapping is applied at the end of this block, around the
    # fully-assembled _rr_text (SGR attrs included). Wrapping the link
    # *inside* an active bold/blink SGR - which the earlier v2 layout did -
    # caused some terminals to misinterpret the escape boundaries and fail
    # to restore attribute state on link exit.

    # Attribute handling (bold, blink). Tokenize on both comma and
    # whitespace so `"bold,blink"` (common typo) matches the same tokens
    # as `"bold blink"`.
    _rr_attr_start=""
    _rr_attr_end=""
    if [ -n "$_seg_attrs" ]; then
      _rr_attrs_norm=$(printf '%s' "$_seg_attrs" | tr ',' ' ')
      case " $_rr_attrs_norm " in
        *" bold "*) _rr_attr_start="${_rr_attr_start}${SL_BOLD}" ;;
      esac
      case " $_rr_attrs_norm " in
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
      _rr_attr_end="${SL_RST}\0033[48;5;${_rr_ebg}m\0033[38;5;${_rr_efg}m"
    fi

    # Build detail suffix (dim inline text for secondary info like ahead/behind).
    # Close the detail with a full SL_RST + BG + FG so the surrounding attr
    # state is cleanly restored: SL_UNDIM alone (\0033[22m) only resets
    # intensity, which some terminals interpret strictly and leave stale
    # color state leaking into powerline transitions.
    _rr_detail=""
    if [ -n "$_seg_detail" ]; then
      _rr_detail=" ${SL_DIM}\0033[38;5;${C_DIM}m${_seg_detail}${SL_RST}\0033[48;5;${_rr_ebg}m\0033[38;5;${_rr_efg}m"
    fi

    # Build padded content
    _rr_text=" ${_rr_attr_start}${_rr_icon}${_seg_content}${_rr_detail}${_rr_attr_end} "

    # OSC 8 link wrap: the escape sequences bracket the entire padded text
    # so any SGR attributes live inside the link rather than straddling it.
    #
    # `\033` (not `\0033`) in a printf FORMAT string: greedy 1-3 octal
    # digits match 033 exactly = ESC. `\0033` would parse as `\003` + `3`
    # and emit an ETX control byte instead.
    if [ "$SL_CAP_OSC8" -eq 1 ] && [ -n "$_seg_link_url" ]; then
      _rr_text=$(printf '\033]8;;%s\a%s\033]8;;\a' "$_seg_link_url" "$_rr_text")
    fi

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
