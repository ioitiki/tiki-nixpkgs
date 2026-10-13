#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#curl nixpkgs#gnused nixpkgs#jq nixpkgs#nix --command bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

channel="${MUSE_CHANNEL:-muse-stable}"
download_url="https://lookaside.facebook.com/lookaside/muse/download/?channel=muse"

# Follow the lookup the official launcher (https://api.meta.ai/muse-launcher.sh)
# performs, channel manifest then release manifest, without executing it.
channel_manifest=$(curl -fsSL "https://api.meta.ai/muse-code/channels/$channel")
version=$(jq -er '.version' <<<"$channel_manifest")
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$ ]]; then
  echo "ERROR: could not determine the Muse Code release version" >&2
  exit 1
fi
manifest_url=$(jq -er '.manifest_url' <<<"$channel_manifest")
if [[ "$manifest_url" != "$download_url&version=$version&file=manifest.json" ]]; then
  echo "ERROR: unexpected release manifest URL: $manifest_url" >&2
  exit 1
fi

release_manifest=$(curl -fsSL "$manifest_url")
if ! jq -e --arg version "$version" \
  '.version == $version and .checksum_algorithm == "sha256"' \
  <<<"$release_manifest" >/dev/null; then
  echo "ERROR: release manifest does not describe $version with SHA-256 checksums" >&2
  exit 1
fi

# Collect and validate every checksum before modifying the package.
platforms=(x86_linux aarch64_linux x86_macos aarch64_macos)
hashes=()
for platform in "${platforms[@]}"; do
  artifact=$(jq -ce --arg platform "$platform" '.artifacts[$platform]' <<<"$release_manifest")
  url=$(jq -er '.url' <<<"$artifact")
  # The package derives this URL from the version, so it must not drift.
  if [[ "$url" != "$download_url&version=$version&file=muse-${platform//_/-}" ]]; then
    echo "ERROR: unexpected artifact URL for $platform: $url" >&2
    exit 1
  fi
  sha256=$(jq -er '.checksum' <<<"$artifact")
  if [[ ! "$sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid SHA-256 checksum for $platform" >&2
    exit 1
  fi
  hashes+=("$(nix hash convert --hash-algo sha256 --to sri "$sha256")")
done

updated=$(mktemp "$SCRIPT_DIR/.package.nix.XXXXXX")
trap 'rm -f "$updated"' EXIT
cp --preserve=mode "$PACKAGE_NIX" "$updated"
sed -i -E "s|^  version = \"[^\"]+\";|  version = \"$version\";|" "$updated"
for i in "${!platforms[@]}"; do
  sed -i -E \
    "s|^(      hash = \")[^\"]+(\"; # update-script: ${platforms[$i]})$|\1${hashes[$i]}\2|" \
    "$updated"
done

if cmp -s "$PACKAGE_NIX" "$updated"; then
  echo "Muse Code is already at $version with current checksums."
else
  mv "$updated" "$PACKAGE_NIX"
  echo "Updated Muse Code to $version."
fi

nix build "$FLAKE_DIR#muse-code" --no-link --accept-flake-config --print-out-paths
