#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#curl nixpkgs#gnused nixpkgs#jq nixpkgs#nix --command bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

release=$(curl -fsSL https://api.github.com/repos/hhanh00/zkool2/releases/latest)
tag=$(jq -er '.tag_name' <<<"$release")
if [[ ! "$tag" =~ ^zkool-v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "ERROR: unrecognized Zkool release tag: $tag" >&2
  exit 1
fi
release_version=${BASH_REMATCH[1]}

# Verify both release artifacts before updating any package metadata.
arches=(x86_64 aarch64)
hashes=()
version=""
for arch in "${arches[@]}"; do
  asset=$(jq -ce --arg suffix "-$arch.deb" '
    [.assets[] | select(.name | endswith($suffix))]
    | if length == 1 then .[0] else error("expected one Debian asset per architecture") end
  ' <<<"$release")
  name=$(jq -er '.name' <<<"$asset")
  asset_version=${name#zkool-}
  asset_version=${asset_version%-"$arch".deb}
  build_number=${asset_version#"$release_version"+}
  if [[ ! "$build_number" =~ ^[0-9]+$ || "$name" != "zkool-$release_version+$build_number-$arch.deb" ]]; then
    echo "ERROR: unexpected release asset: $name" >&2
    exit 1
  fi
  if [[ -n "$version" && "$version" != "$asset_version" ]]; then
    echo "ERROR: release assets have different build versions" >&2
    exit 1
  fi
  version=$asset_version
  digest=$(jq -er '.digest' <<<"$asset")
  if [[ ! "$digest" =~ ^sha256:([0-9a-f]{64})$ ]]; then
    echo "ERROR: missing or invalid SHA-256 digest for $name" >&2
    exit 1
  fi
  hash=$(nix hash convert --hash-algo sha256 --to sri "${BASH_REMATCH[1]}")
  hashes+=("$hash")
  url="https://github.com/hhanh00/zkool2/releases/download/$tag/$name"
  nix store prefetch-file --json --name "$name" --expected-hash "$hash" "$url" >/dev/null
done

updated=$(mktemp "$SCRIPT_DIR/.package.nix.XXXXXX")
trap 'rm -f "$updated"' EXIT
cp --preserve=mode "$PACKAGE_NIX" "$updated"
sed -i -E "s|^  version = \"[^\"]+\";|  version = \"$version\";|" "$updated"
for i in "${!arches[@]}"; do
  sed -i -E \
    "s|^(      hash = \")[^\"]+(\"; # update-script: ${arches[$i]})$|\1${hashes[$i]}\2|" \
    "$updated"
done

if cmp -s "$PACKAGE_NIX" "$updated"; then
  echo "Zkool is already at $version with verified release artifacts."
else
  mv "$updated" "$PACKAGE_NIX"
  echo "Updated Zkool to $version."
fi

nix build "$FLAKE_DIR#zkool" --no-link --accept-flake-config --print-out-paths
