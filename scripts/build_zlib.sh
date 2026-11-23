#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX:-}" ]]; then
  echo "Error: PREFIX must be set" >&2
  exit 1
fi

if [[ -z "${ZLIB_VERSION:-}" ]]; then
  echo "Error: ZLIB_VERSION must be set" >&2
  exit 1
fi

mkdir -p "$PREFIX/src"
source "$(dirname "${BASH_SOURCE[0]}")/build_sources.sh"
cd "$PREFIX/src"
archive=$(source_build_archive zlib "$ZLIB_VERSION")
rm -rf "zlib-${ZLIB_VERSION}"
tar xzf "$archive"
cd "zlib-${ZLIB_VERSION}"

./configure \
  --prefix="$PREFIX" \
  --static

make -j"$(nproc)"
make install

rm -rf "$PREFIX/src"
