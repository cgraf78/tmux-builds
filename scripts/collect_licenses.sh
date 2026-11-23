#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/tmp/build}"

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTDIR}/../versions.env"
source "${SCRIPTDIR}/tmux_source.sh"
source "${SCRIPTDIR}/build_sources.sh"
TMUX_REF="$(tmux_source_ref)"

mkdir -p "$PREFIX/licenses"
license_dir=$(cd "$PREFIX/licenses" && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

# Read only the license member from the same verified archives as the build.
collect_license() (
  local package=$1 version=$2 member=$3 output=$4 archive
  echo "Collecting $package license..."
  cd "$scratch"
  archive=$(source_build_archive "$package" "$version")
  tar -xOzf "$archive" "$member" >"$license_dir/$output"
)

collect_license libevent "$LIBEVENT_VERSION" "libevent-$LIBEVENT_VERSION-stable/LICENSE" LICENSE.libevent
collect_license musl "$MUSL_VERSION" "musl-$MUSL_VERSION/COPYRIGHT" COPYRIGHT.musl
collect_license ncurses "$NCURSES_VERSION" "ncurses-$NCURSES_VERSION/COPYING" COPYING.ncurses
collect_license zlib "$ZLIB_VERSION" "zlib-$ZLIB_VERSION/README" LICENSE.zlib
collect_license utf8proc "$UTF8PROC_VERSION" "utf8proc-$UTF8PROC_VERSION/LICENSE.md" LICENSE.utf8proc
if [[ $TMUX_VERSION == preview ]]; then
  wget --tries=3 --timeout=30 -q "https://raw.githubusercontent.com/tmux/tmux/$TMUX_REF/COPYING" -O "$license_dir/COPYING.tmux"
else
  collect_license tmux "$TMUX_REF" "tmux-$TMUX_REF/COPYING" COPYING.tmux
fi

# Create archive
echo "Creating archive..."
tar czf "${PREFIX}/LICENSES.tar.gz" -C "$PREFIX/licenses" .
rm -rf "$PREFIX/licenses"

echo "Licenses collected in ${PREFIX}/LICENSES.tar.gz"
