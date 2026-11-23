#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX:-}" ]]; then
  echo "Error: PREFIX must be set" >&2
  exit 1
fi

if [[ -z "${LIBEVENT_VERSION:-}" ]]; then
  echo "Error: LIBEVENT_VERSION must be set" >&2
  exit 1
fi

mkdir -p "$PREFIX/src"
source "$(dirname "${BASH_SOURCE[0]}")/build_sources.sh"
cd "$PREFIX/src"
archive=$(source_build_archive libevent "$LIBEVENT_VERSION")
tar xzf "$archive"
cd "libevent-${LIBEVENT_VERSION}-stable"

./configure \
  --prefix="$PREFIX" \
  --includedir="$PREFIX/include" \
  --libdir="$PREFIX/lib" \
  --disable-shared \
  --disable-openssl \
  --disable-libevent-regress \
  --disable-samples

make -j"$(nproc)"
make install

rm -rf "$PREFIX/src"
