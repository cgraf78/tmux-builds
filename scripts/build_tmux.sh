#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX:-}" ]]; then
  echo "Error: PREFIX must be set" >&2
  exit 1
fi

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTDIR}/tmux_source.sh"
source "${SCRIPTDIR}/build_sources.sh"
TMUX_REF="$(tmux_source_ref)"

mkdir -p "$PREFIX/src"
cd "$PREFIX/src"

if [[ "${TMUX_VERSION}" == "preview" ]]; then
  git init -q tmux
  cd tmux
  git fetch --depth=1 https://github.com/tmux/tmux.git "$TMUX_REF"
  git checkout --detach FETCH_HEAD
  sh autogen.sh
else
  archive=$(source_build_archive tmux "$TMUX_REF")
  tar xzf "$archive"
  cd "tmux-${TMUX_REF}"
fi

IS_MACOS=false
if [[ "$(uname)" == "Darwin" ]]; then
  IS_MACOS=true
fi

CONFIGURE_FLAGS=(
  --enable-sixel
  --prefix="${PREFIX}"
  --includedir="${PREFIX}/include"
  --libdir="${PREFIX}/lib"
  LIBEVENT_LIBS="-L${PREFIX}/lib -levent"
  LIBNCURSES_CFLAGS="-I${PREFIX}/include/ncurses"
  LIBNCURSES_LIBS="-L${PREFIX}/lib -lncurses"
  LIBTINFO_CFLAGS="-I${PREFIX}/include/ncurses"
  LIBTINFO_LIBS="-L${PREFIX}/lib -ltinfo"
  CFLAGS="-I${PREFIX}/include"
  LDFLAGS="-L${PREFIX}/lib"
  CPPFLAGS="-I${PREFIX}/include"
)

if $IS_MACOS; then
  CONFIGURE_FLAGS+=(
    --enable-utf8proc
    LIBUTF8PROC_CFLAGS="-I${PREFIX}/include"
    LIBUTF8PROC_LIBS="${PREFIX}/lib/libutf8proc.a"
    --disable-jemalloc
  )
else
  CONFIGURE_FLAGS+=(
    --enable-static
  )
fi

./configure "${CONFIGURE_FLAGS[@]}"
tmux_stamp_version Makefile

if $IS_MACOS; then
  make -j"$(sysctl -n hw.ncpu)"
else
  make -j"$(nproc)"
fi

make install

rm -rf "$PREFIX/src"
