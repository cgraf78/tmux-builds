# shellcheck shell=bash

# Resolve the digest for the exact upstream stable asset once, before the
# build matrix. Preview builds use an immutable Git commit instead.
tmux_release_sha() (
  local version=$1 expected metadata digest
  [[ $version =~ ^[0-9]+(\.[0-9]+)+[a-z]?$ ]] || return 1
  expected="tmux-$version.tar.gz"
  metadata=$(gh api "repos/tmux/tmux/releases/tags/$version") || return
  digest=$(jq -er --arg name "$expected" '
    [.assets[] | select(.name == $name and .state == "uploaded")]
    | select(length == 1) | .[0].digest | strings
    | select(test("^sha256:[a-f0-9]{64}$"))
  ' <<<"$metadata") || {
    printf 'No unique SHA-256 digest for %s in the upstream release\n' "$expected" >&2
    return 1
  }
  printf '%s\n' "${digest#sha256:}"
)

# The builds project's latest release is the source of truth for stable builds.
latest_upstream_tag() {
  local tag
  tag=$(gh api repos/tmux/tmux-builds/releases/latest \
    --jq 'select(.draft == false and .prerelease == false) | .tag_name') || return 1
  if [[ -n "$tag" && ! "$tag" =~ ^v[0-9]+(\.[0-9]+)+[a-z]?$ ]]; then
    printf 'Unexpected upstream stable release tag: %s\n' "$tag" >&2
    return 1
  fi
  printf '%s\n' "$tag"
}

# An equal or newer downstream release keeps the schedule from backfilling old versions.
version_covered() {
  local repo="$1" upstream_tag="$2" tag tags
  tags=$(gh api --paginate "repos/$repo/releases?per_page=100" \
    --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name') || return 1
  while IFS= read -r tag; do
    if [[ "$tag" =~ ^v[0-9]+(\.[0-9]+)+[a-z]?(-[0-9]+)?$ ]] &&
      sort -V -C <<<"$upstream_tag"$'\n'"${tag%%-*}"; then
      printf 'true\n'
      return
    fi
  done <<<"$tags"
  printf 'false\n'
}

# A tag left by an interrupted publication pins retries to the same build commit.
release_tag_commit() {
  local repo="$1" tag="$2" ref refs
  refs=$(gh api "repos/$repo/git/matching-refs/tags/$tag" --jq '.[].ref') || return 1
  while IFS= read -r ref; do
    if [[ "$ref" == "refs/tags/$tag" ]]; then
      gh api "repos/$repo/commits/refs%2Ftags%2F$tag" --jq '.sha'
      return
    fi
  done <<<"$refs"
}
