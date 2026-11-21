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
