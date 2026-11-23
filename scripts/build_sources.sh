# shellcheck shell=bash

build_source_pins=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/source-pins.tsv

# A failed transfer may leave a partial file. Reuse the same temporary
# pathname for the next mirror and publish only verified bytes.
download_verified() (
  local archive=$1 expected=$2 stage actual url status
  shift 2
  if [[ ! $expected =~ ^[a-f0-9]{64}$ || -d $archive ]]; then
    printf 'Invalid archive destination or SHA-256 pin for %s\n' "$archive" >&2
    return 1
  fi
  stage=$(mktemp "${archive}.XXXXXX") || return
  trap 'rm -f -- "$stage"' EXIT
  for url in "$@"; do
    # Wget's verbose redirect log includes signed storage URLs. Report the
    # requested upstream URL and status ourselves if the transfer fails.
    if wget --quiet --tries=3 --timeout=30 -O "$stage" "$url"; then
      if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum <"$stage") || return
      else
        actual=$(shasum -a 256 <"$stage") || return
      fi
      if [[ ${actual%% *} != "$expected" ]]; then
        printf 'SHA-256 mismatch for %s from %s\n' "$archive" "$url" >&2
        return 1
      fi
      mv -f -- "$stage" "$archive"
      return
    else
      status=$?
    fi
    printf 'Download failed from %s (wget exit %s)\n' "$url" "$status" >&2
  done
  printf 'Could not download %s from any mirror\n' "$archive" >&2
  return 1
)

# Print the checked-in checksum for an exact package version.
source_pin() {
  awk -v name="$1" -v version="$2" '
    $1 == name && ("v" $2) == ("v" version) { checksum = $3; matches++ }
    END { if (matches == 1) print checksum; else exit 1 }
  ' "$build_source_pins"
}

# Print the archive path only after the selected upstream bytes verify.
source_build_archive() (
  local package=$1 version=$2 archive expected
  local urls=()
  [[ $version =~ ^[0-9]+(\.[0-9]+)+[a-z]?$ ]] || return 1
  if ! expected=$(source_pin "$package" "$version"); then
    # Setup looks up a newly published stable tmux version before the matrix.
    if [[ $package == tmux && -n ${TMUX_SHA256:-} ]]; then
      expected=$TMUX_SHA256
    else
      printf 'No SHA-256 pin for %s %s in source-pins.tsv\n' "$package" "$version" >&2
      return 1
    fi
  fi
  archive="$package-$version.tar.gz"
  case $package in
    libevent)
      archive="libevent-$version-stable.tar.gz"
      urls=("https://github.com/libevent/libevent/releases/download/release-$version-stable/$archive")
      ;;
    musl) urls=("https://musl.libc.org/releases/$archive") ;;
    ncurses) urls=("https://invisible-island.net/archives/ncurses/$archive" "https://ftp.gnu.org/gnu/ncurses/$archive") ;;
    tmux) urls=("https://github.com/tmux/tmux/releases/download/$version/$archive") ;;
    utf8proc) urls=("https://github.com/JuliaStrings/utf8proc/releases/download/v$version/$archive") ;;
    zlib)
      # zlib.net only retains the latest release. GitHub is the durable mirror.
      urls=("https://www.zlib.net/$archive" "https://github.com/madler/zlib/releases/download/v$version/$archive")
      ;;
    *) return 1 ;;
  esac
  download_verified "$archive" "$expected" "${urls[@]}" || return
  printf '%s\n' "$archive"
)
