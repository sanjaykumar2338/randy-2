#!/usr/bin/env bash

# Read a literal KEY=value entry without executing the file. The last active
# occurrence wins, matching common dotenv behavior. Values containing spaces
# are preserved and matching surrounding single/double quotes are removed.
dotenv_get() {
  local file="$1" key="$2" line name value found="" matched=0
  [ -f "$file" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    line="${line#export }"
    case "$line" in *=*) ;; *) continue ;; esac
    name="${line%%=*}"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [ "$name" = "$key" ] || continue
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    if [ "${#value}" -ge 2 ]; then
      case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
      esac
    fi
    found="$value"
    matched=1
  done < "$file"

  [ "$matched" -eq 1 ] || return 1
  printf '%s\n' "$found"
}

dotenv_default() {
  local file="$1" key="$2" fallback="$3" current
  current="${!key:-}"
  if [ -n "$current" ]; then
    printf '%s\n' "$current"
  elif dotenv_get "$file" "$key"; then
    :
  else
    printf '%s\n' "$fallback"
  fi
}

project_path() {
  local root="$1" path="$2"
  case "$path" in
    '') printf '\n' ;;
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$root" "$path" ;;
  esac
}
