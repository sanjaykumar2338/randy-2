#!/usr/bin/env bash

has_active_empty_sv_master1() {
  printf '%s\n' "$1" | grep -Eq "^[[:space:]]*sv_master1[[:space:]]+(\"\"|'')[[:space:]]*([#;].*)?$"
}

loaded_config_disables_public_listing() {
  local config_path="$1"
  local root_dir="$2"
  local canonical line trimmed include include_path

  canonical="$(cd "$(dirname "$config_path")" 2>/dev/null && pwd -P)/$(basename "$config_path")" || return 1
  case "|${PUBLIC_LISTING_VISITED:-}|" in
    *"|$canonical|"*) return 1 ;;
  esac
  PUBLIC_LISTING_VISITED="${PUBLIC_LISTING_VISITED:-}|$canonical"

  while IFS= read -r line || [ -n "$line" ]; do
    if has_active_empty_sv_master1 "$line"; then
      return 0
    fi

    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in
      \#*|\;*|'') continue ;;
      exec[[:space:]]*)
        include="${trimmed#exec}"
        include="${include#"${include%%[![:space:]]*}"}"
        include="${include%%[[:space:]#;]*}"
        include="${include#\"}"; include="${include%\"}"
        include="${include#\'}"; include="${include%\'}"
        if [ -f "$root_dir/$include" ]; then
          include_path="$root_dir/$include"
        else
          include_path="$(dirname "$canonical")/$include"
        fi
        if [ -f "$include_path" ] && loaded_config_disables_public_listing "$include_path" "$root_dir"; then
          return 0
        fi
        ;;
    esac
  done < "$canonical"

  return 1
}
