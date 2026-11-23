#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX:-}" ]]; then
  echo "Error: PREFIX must be set" >&2
  exit 1
fi

if [[ -z "${MUSL_VERSION:-}" ]]; then
  echo "Error: MUSL_VERSION must be set" >&2
  exit 1
fi

mkdir -p "$PREFIX/src"
source "$(dirname "${BASH_SOURCE[0]}")/build_sources.sh"
cd "$PREFIX/src"
archive=$(source_build_archive musl "$MUSL_VERSION")
tar xzf "$archive"
cd "musl-${MUSL_VERSION}"

./configure \
  --enable-gcc-wrapper \
  --disable-shared \
  --prefix="${PREFIX}"

make -j"$(nproc)"
make install

rm -rf "$PREFIX/src"
