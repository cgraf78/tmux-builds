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

# SHA256 of the zlib tarball for ZLIB_VERSION. Update this when bumping
# ZLIB_VERSION; a mismatch fails the build loudly rather than building
# a truncated or tampered archive.
ZLIB_SHA256="02dd159783677a749c04adbdd02b55b8a2bcc7e054f51b76b549199a916ad584"

mkdir -p "$PREFIX/src"
cd "$PREFIX/src"

# zlib.net keeps only the latest release, so an older pinned version 404s
# there; the GitHub release asset is the durable mirror. Download with
# -O so a partial download from a failed attempt is overwritten instead
# of landing as a .1 file while tar extracts the truncated original.
ZLIB_TARBALL="zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_DOWNLOAD_URLS=(
    "https://www.zlib.net/${ZLIB_TARBALL}"
    "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/${ZLIB_TARBALL}"
)
download_succeeded=false
for download_url in "${ZLIB_DOWNLOAD_URLS[@]}"; do
    rm -f "$ZLIB_TARBALL"
    if wget --tries=3 --timeout=30 -O "$ZLIB_TARBALL" "$download_url"; then
        download_succeeded=true
        break
    fi
    echo "Download from $download_url failed, trying next mirror" >&2
done
if [[ "$download_succeeded" != true ]]; then
    echo "Error: could not download $ZLIB_TARBALL from any mirror" >&2
    exit 1
fi

download_sha="$(sha256sum "$ZLIB_TARBALL" | awk '{print $1}')"
if [[ "$download_sha" != "$ZLIB_SHA256" ]]; then
    echo "Error: SHA256 mismatch for $ZLIB_TARBALL: got $download_sha, want $ZLIB_SHA256" >&2
    exit 1
fi

rm -rf "zlib-${ZLIB_VERSION}"
tar xzf "zlib-${ZLIB_VERSION}.tar.gz"
cd "zlib-${ZLIB_VERSION}"

./configure \
    --prefix="$PREFIX" \
    --static

make -j"$(nproc)"
make install

rm -rf "$PREFIX/src"
