#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#curl nixpkgs#gnused nixpkgs#nix --command bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

# Read the official installer as release metadata; never execute it.
installer=$(curl -fsSL https://app.factory.ai/cli)
version=$(sed -nE 's/^VER="([^"]+)"$/\1/p' <<<"$installer")
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: could not determine the Factory CLI release version" >&2
  exit 1
fi

# Collect and validate every checksum before modifying the package.
platforms=(linux/x64-baseline linux/arm64 darwin/arm64)
hashes=()
for platform in "${platforms[@]}"; do
  sha256=$(curl -fsSL "https://downloads.factory.ai/factory-cli/releases/$version/$platform/droid.sha256")
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
  echo "Factory is already at $version with current checksums."
else
  mv "$updated" "$PACKAGE_NIX"
  echo "Updated Factory to $version."
fi

nix build "$FLAKE_DIR#factory" --no-link --accept-flake-config --print-out-paths
