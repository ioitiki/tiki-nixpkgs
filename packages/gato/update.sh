#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#curl nixpkgs#gnugrep nixpkgs#gnused nixpkgs#nix --command bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"
BASE_URL="https://releases.gato-chainstarters.com"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [version-build] (defaults to the offered release)" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?-[1-9][0-9]*$ ]]; then
    echo "ERROR: expected <version>-<build>, e.g. 0.1.3-1649" >&2
    exit 1
  fi
  record_url="$BASE_URL/gato-$1-linux-x86_64.release"
else
  record_url="$BASE_URL/gato-linux-x86_64.release"
fi

record="$(curl -fsSL "$record_url")"

field() {
  local name="$1" count
  count="$(grep -c "^${name}=" <<<"$record" || true)"
  if [[ "$count" != "1" ]]; then
    echo "ERROR: release record from $record_url has $count lines for $name" >&2
    exit 1
  fi
  sed -n "s/^${name}=//p" <<<"$record"
}

release_version="$(field version)"
build="$(field build)"
tar_sha256="$(field tar_sha256)"

if [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || \
   [[ ! "$build" =~ ^[1-9][0-9]*$ ]] || \
   [[ ! "$tar_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: invalid release record from $record_url" >&2
  exit 1
fi

full_version="${release_version}-${build}"
asset="gato-${full_version}-linux-x86_64.tar.gz"
url="${BASE_URL}/${asset}"
hash="$(nix hash convert --hash-algo sha256 --to sri "$tar_sha256")"

nix store prefetch-file --json --name "$asset" --expected-hash "$hash" "$url" >/dev/null

updated="$(mktemp "$SCRIPT_DIR/.package.nix.XXXXXX")"
trap 'rm -f "$updated"' EXIT
cp --preserve=mode "$PACKAGE_NIX" "$updated"
sed -i -E \
  -e "s|^  version = \"[^\"]+\";|  version = \"$full_version\";|" \
  -e "s|^    hash = \"[^\"]+\";|    hash = \"$hash\";|" \
  "$updated"

if cmp -s "$PACKAGE_NIX" "$updated"; then
  echo "gato is already at $full_version with verified release archive."
else
  mv "$updated" "$PACKAGE_NIX"
  echo "Updated gato to $full_version."
fi

nix build "$FLAKE_DIR#gato" --no-link --accept-flake-config --print-out-paths
