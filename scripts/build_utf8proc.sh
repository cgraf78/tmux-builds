#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PREFIX:-}" ]]; then
  echo "Error: PREFIX must be set"
  exit 1
fi

if [[ -z "${UTF8PROC_VERSION:-}" ]]; then
  echo "Error: UTF8PROC_VERSION must be set"
  exit 1
fi

mkdir -p "$PREFIX/src"
source "$(dirname "${BASH_SOURCE[0]}")/build_sources.sh"
cd "$PREFIX/src"
archive=$(source_build_archive utf8proc "$UTF8PROC_VERSION")
tar xzf "$archive"
cd "utf8proc-${UTF8PROC_VERSION}"

make -j"$(sysctl -n hw.ncpu)"
make prefix="$PREFIX" install

rm -rf "$PREFIX/src"
