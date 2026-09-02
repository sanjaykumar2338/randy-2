#!/usr/bin/env bash

read_fxserver_manifest_value() {
  local manifest_path="$1" property="$2"
  awk -v target="\"$property\":" '
    $1 == target {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/[[:space:]]*,?[[:space:]]*$/, "")
      sub(/^"/, "")
      sub(/"$/, "")
      print
      found = 1
    }
    END { if (!found) exit 1 }
  ' "$manifest_path"
}

# Validates only the pinned Enhanced artifact, or the stable enhanced-129 path
# when that path resolves to the pinned directory. It deliberately rejects an
# arbitrary executable run.sh elsewhere on disk.
validate_pinned_fxserver_linux_artifact() {
  local root_dir="$1" configured_launcher="${2:-}"
  local manifest_path="$root_dir/config/fxserver-linux-artifact.json"
  local build channel launcher executable expected_dir active_dir candidate
  local expected_real candidate_real install_manifest manifest_build manifest_channel

  command -v readlink >/dev/null 2>&1 || {
    printf 'readlink is required to validate the pinned Linux artifact\n' >&2
    return 1
  }
  [ -f "$manifest_path" ] || {
    printf 'Pinned Linux artifact manifest is missing: %s\n' "$manifest_path" >&2
    return 1
  }

  build="$(read_fxserver_manifest_value "$manifest_path" build)" || return 1
  channel="$(read_fxserver_manifest_value "$manifest_path" channel)" || return 1
  launcher="$(read_fxserver_manifest_value "$manifest_path" launcher)" || return 1
  executable="$(read_fxserver_manifest_value "$manifest_path" executable)" || return 1
  [[ "$build" =~ ^[0-9]+$ ]] && [ "$channel" = enhanced ] \
    && [ "$launcher" = run.sh ] && [ "$executable" = alpine/opt/cfx-server/cfx-server ] || {
      printf 'Pinned Linux artifact manifest has unexpected build/channel/layout values\n' >&2
      return 1
    }

  expected_dir="$root_dir/server-binaries/enhanced-linux-$build"
  active_dir="$root_dir/server-binaries/enhanced-129"
  [ -d "$expected_dir" ] || {
    printf 'Pinned Enhanced Linux artifact directory is missing: %s\n' "$expected_dir" >&2
    return 1
  }
  expected_real="$(readlink -f -- "$expected_dir")" || return 1

  candidate=""
  if [ -n "$configured_launcher" ] && [ -e "$configured_launcher" ]; then
    candidate="$configured_launcher"
  elif [ -e "$active_dir/$launcher" ]; then
    candidate="$active_dir/$launcher"
  elif [ -e "$expected_dir/$launcher" ]; then
    candidate="$expected_dir/$launcher"
  fi
  [ -n "$candidate" ] || {
    printf 'No launcher was found for pinned Enhanced Linux build %s\n' "$build" >&2
    return 1
  }

  candidate_real="$(readlink -f -- "$(dirname "$candidate")")" || return 1
  [ "$candidate_real" = "$expected_real" ] || {
    printf 'Configured launcher does not resolve to pinned Enhanced Linux build %s\n' "$build" >&2
    return 1
  }
  [ -x "$candidate" ] || {
    printf 'Pinned Enhanced Linux launcher is not executable: %s\n' "$candidate" >&2
    return 1
  }
  [ -x "$candidate_real/$executable" ] || {
    printf 'Pinned Enhanced Linux cfx-server binary is missing or not executable\n' >&2
    return 1
  }

  install_manifest="$candidate_real/INSTALL-MANIFEST.txt"
  if [ -f "$install_manifest" ]; then
    manifest_build="$(sed -n 's/^build=//p' "$install_manifest" | tail -n 1)"
    manifest_channel="$(sed -n 's/^channel=//p' "$install_manifest" | tail -n 1)"
    [ "$manifest_build" = "$build" ] && [ "$manifest_channel" = "$channel" ] || {
      printf 'Installed artifact metadata does not match pinned build/channel\n' >&2
      return 1
    }
  fi

  printf '%s|%s|%s\n' "$build" "$candidate" "$(if [ -f "$install_manifest" ]; then printf verified; else printf layout-only; fi)"
}
