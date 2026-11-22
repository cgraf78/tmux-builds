# shellcheck shell=bash

# Print the upstream release tag, preview pin, or standalone preview branch.
tmux_source_ref() {
  local version="${TMUX_VERSION:-}"
  if [[ -z "$version" ]]; then
    echo "Error: TMUX_VERSION must be set" >&2
    return 1
  fi
  if [[ "$version" == "preview" ]]; then
    # CI always supplies the variable. An empty setup output must fail there.
    if [[ -z "${TMUX_UPSTREAM_SHA+x}" ]]; then
      version=master
    elif [[ ! "$TMUX_UPSTREAM_SHA" =~ ^[0-9a-f]{40}$ ]]; then
      echo "Error: TMUX_UPSTREAM_SHA must be a full 40-character commit SHA when set for a preview" >&2
      return 1
    else
      version="$TMUX_UPSTREAM_SHA"
    fi
  fi
  printf '%s\n' "$version"
}

# Stamp the generated compiler definition so the upstream release source and
# its Autoconf metadata remain usable for local and preview builds.
tmux_stamp_version() {
  local makefile="$1" reported="${TMUX_REPORTED_VERSION:-}"
  local previous replacement temporary
  [[ -n "$reported" ]] || return 0
  if [[ ! "$reported" =~ ^[0-9]+(\.[0-9]+)+[a-z]?(-[0-9]+)?\+[A-Za-z0-9-]+$ ]]; then
    echo "Error: invalid TMUX_REPORTED_VERSION: $reported" >&2
    return 1
  fi
  previous="-DTMUX_VERSION='\"$TMUX_VERSION\"'"
  replacement="-DTMUX_VERSION='\"$reported\"'"
  temporary=$(mktemp "$makefile.XXXXXX") || return 1
  if ! awk -v old="$previous" -v new="$replacement" '
    {
      position = index($0, old)
      if (position) {
        rest = substr($0, position + length(old))
        if (index(rest, old)) exit 1
        $0 = substr($0, 1, position - 1) new rest
        replacements++
      }
      print
    }
    END { if (replacements != 1) exit 1 }
  ' "$makefile" >"$temporary"; then
    unlink "$temporary"
    echo "Error: expected one upstream TMUX_VERSION compiler definition in $makefile" >&2
    return 1
  fi
  mv "$temporary" "$makefile"
}
