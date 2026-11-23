#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/release_policy.sh

# Run the same jq filters as gh, without reaching any live repository.
gh() {
  local query="${!#}"
  if [[ "$response" == error ]]; then
    return 1
  fi
  if [[ "$*" == *'/commits/'* ]]; then
    jq -r "$query" <<<'{"sha":"1234567890abcdef1234567890abcdef12345678"}'
    return
  fi
  if [[ "$*" == 'api repos/tmux/tmux/releases/tags/3.9' ]]; then
    printf '%s\n' "$response"
    return
  fi
  jq -r "$query" <<<"$response"
}

expect() {
  local expected="$1" actual
  shift
  actual=$("$@")
  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected %s, got %s from %s\n' "$expected" "$actual" "$*" >&2
    return 1
  fi
}

digest=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
response='{"assets":[{"name":"tmux-3.9.tar.gz","state":"uploaded","digest":"sha256:'$digest'"}]}'
expect "$digest" tmux_release_sha 3.9
response=$(jq -c '.assets += .assets' <<<"$response")
if tmux_release_sha 3.9 2>/dev/null; then
  echo 'Ambiguous upstream tmux asset accepted' >&2
  exit 1
fi
response='{"assets":[{"name":"tmux-3.9.tar.gz","state":"uploaded","digest":null}]}'
if tmux_release_sha 3.9 2>/dev/null; then
  echo 'Missing upstream tmux digest accepted' >&2
  exit 1
fi

response='{"tag_name":"v3.8","draft":false,"prerelease":false}'
expect v3.8 latest_upstream_tag

response='{"tag_name":"v3.9","draft":false,"prerelease":true}'
expect '' latest_upstream_tag

response='{"tag_name":"v3.9","draft":true,"prerelease":false}'
expect '' latest_upstream_tag

response='{"tag_name":"preview","draft":false,"prerelease":false}'
if latest_upstream_tag 2>/dev/null; then
  echo 'Unexpected upstream stable tag was accepted' >&2
  exit 1
fi

response='[{"tag_name":"v3.8-2","draft":false,"prerelease":false}]'
expect true version_covered downstream/builds v3.8

response='[{"tag_name":"v3.8","draft":false,"prerelease":false}]'
expect true version_covered downstream/builds v3.8

response='[{"tag_name":"v3.8-1","draft":true,"prerelease":false}]'
expect false version_covered downstream/builds v3.8

response='[{"tag_name":"v3.8-1","draft":false,"prerelease":true}]'
expect false version_covered downstream/builds v3.8

response='[{"tag_name":"v3.8-rc1","draft":false,"prerelease":false}]'
expect false version_covered downstream/builds v3.8

response='[{"tag_name":"v3.7c-1","draft":false,"prerelease":false}]'
expect false version_covered downstream/builds v3.8

response='[{"tag_name":"v3.8-2","draft":false,"prerelease":false}]'
expect false version_covered downstream/builds v3.8a

response='[{"tag_name":"v3.10-2","draft":false,"prerelease":false}]'
expect true version_covered downstream/builds v3.9

response='[{"ref":"refs/tags/v3.8-10"}]'
expect '' release_tag_commit downstream/builds v3.8-1

response='[{"ref":"refs/tags/v3.8-1"}]'
expect 1234567890abcdef1234567890abcdef12345678 release_tag_commit downstream/builds v3.8-1

response=error
if latest_upstream_tag || version_covered downstream/builds v3.8 || release_tag_commit downstream/builds v3.8-1; then
  echo 'An API failure was treated as a release lookup result' >&2
  exit 1
fi

echo 'Release policy tests passed.'
