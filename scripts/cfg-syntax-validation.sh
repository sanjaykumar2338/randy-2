#!/usr/bin/env bash

find_two_argument_directives_with_one_argument() {
  local config_path="$1"
  awk '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line == "" || line ~ /^[#;]/) next
      if (line ~ /^(set|setr|sets|add_principal|remove_principal)[[:space:]]+[^[:space:]#;]+[[:space:]]*([#;].*)?$/) {
        print FNR
      }
    }
  ' "$config_path"
}
