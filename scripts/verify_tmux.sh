#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX:-}" ]]; then
  echo "Error: PREFIX must be set" >&2
  exit 1
fi

tmux_bin="$PREFIX/bin/tmux"
file "$tmux_bin"

if [[ "$(uname)" == "Darwin" ]]; then
  otool -L "$tmux_bin"
else
  ldd "$tmux_bin" || true
fi

version="$("$tmux_bin" -V)"
echo "$version"
expected_version="${TMUX_REPORTED_VERSION:-${TMUX_VERSION:-}}"
if [[ -n "$expected_version" && "$expected_version" != preview && "$version" != "tmux $expected_version" ]]; then
  echo "Error: expected tmux $expected_version, got $version" >&2
  exit 1
fi

scratch=
cleanup() {
  if [[ -n "$scratch" ]]; then
    "$tmux_bin" -N -S "$scratch/socket" kill-server 2>/dev/null || true
    # tmux can leave the socket file behind after the server exits.
    unlink "$scratch/socket" 2>/dev/null || true
    rmdir "$scratch"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Keep the socket path short for macOS and isolated from existing servers.
scratch="$(mktemp -d /tmp/tmux-verify.XXXXXX)"
unset TMUX
"$tmux_bin" -S "$scratch/socket" -f /dev/null new-session -d -s test /bin/sleep 60
server_version="$("$tmux_bin" -N -S "$scratch/socket" display-message -p '#{version}')"
if [[ "tmux $server_version" != "$version" ]]; then
  echo "Error: server reports $server_version, expected ${version#tmux }" >&2
  exit 1
fi
sixel_support="$("$tmux_bin" -N -S "$scratch/socket" display-message -p '#{sixel_support}')"
if [[ "$sixel_support" != 1 ]]; then
  echo "Error: expected tmux sixel_support=1, got '${sixel_support}'" >&2
  exit 1
fi
echo "tmux sixel_support=$sixel_support"
