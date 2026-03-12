#!/bin/sh
# segments/model.sh -- Model name, tier-colored
# Reads: sl_model_id, sl_model_short, _sl_tier
# Sets: sl_model_bg (for agent.sh to reuse)

segment_model() {
  [ -z "$sl_model_short" ] && return 1

  _seg_weight="primary"
  _seg_min_tier="micro"
  _seg_group="session"
  _seg_icon="$GL_MODEL"
  _seg_attrs=""

  # Detect tier colors
  case "$sl_model_id" in
    *opus*)   _seg_bg=$C_OPUS_BG;   _seg_fg=$C_OPUS_FG   ;;
    *sonnet*) _seg_bg=$C_SONNET_BG; _seg_fg=$C_SONNET_FG ;;
    *haiku*)  _seg_bg=$C_HAIKU_BG;  _seg_fg=$C_HAIKU_FG  ;;
    *)        _seg_bg=$C_BASE_BG;   _seg_fg=$C_BASE_FG   ;;
  esac

  # Store for agent segment to reuse
  sl_model_bg=$_seg_bg
  sl_model_fg=$_seg_fg

  # Tier-aware content
  case "$_sl_tier" in
    micro)
      # Abbreviate: "Opus 4.6" -> "Op 4.6"; single words pass through
      case "$sl_model_short" in
        *" "*)
          _m_name="${sl_model_short%% *}"
          _m_ver="${sl_model_short#* }"
          _seg_content="$(printf '%.2s' "$_m_name") ${_m_ver}"
          ;;
        *)
          _seg_content="$sl_model_short"
          ;;
      esac
      ;;
    *)
      _seg_content="$sl_model_short"
      ;;
  esac

  return 0
}
