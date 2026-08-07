#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#cachix nixpkgs#coreutils nixpkgs#curl nixpkgs#gnused nixpkgs#jq nixpkgs#nix --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

release_json=$(curl -fsSL "https://api.github.com/repos/stablyai/orca/releases/latest")
version=$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' <<<"$release_json")
current_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$PACKAGE_NIX")

echo "Latest Orca version: $version"
echo "Current Orca version: $current_version"

if [[ "$version" == "$current_version" ]]; then
  echo "Already at the latest version."
  exit 0
fi

release_has_asset() {
  local asset=$1
  jq -e --arg asset "$asset" '.assets | any(.name == $asset)' <<<"$release_json" >/dev/null
}

release_hash() {
  local metadata_asset=$1
  local appimage_asset=$2
  local metadata metadata_version metadata_path hash

  release_has_asset "$metadata_asset"
  release_has_asset "$appimage_asset"

  metadata=$(curl -fsSL "https://github.com/stablyai/orca/releases/download/v${version}/${metadata_asset}")
  metadata_version=$(sed -nE '0,/^version: /s/^version: (.+)$/\1/p' <<<"$metadata")
  metadata_path=$(sed -nE '0,/^path: /s/^path: (.+)$/\1/p' <<<"$metadata")
  hash=$(sed -nE '0,/^sha512: /s/^sha512: (.+)$/\1/p' <<<"$metadata")

  if [[ "$metadata_version" != "$version" || "$metadata_path" != "$appimage_asset" || -z "$hash" ]]; then
    echo "ERROR: Invalid metadata in $metadata_asset" >&2
    exit 1
  fi

  printf 'sha512-%s' "$hash"
}

x86_64_hash=$(release_hash "latest-linux.yml" "orca-linux.AppImage")
aarch64_hash=$(release_hash "latest-linux-arm64.yml" "orca-linux-arm64.AppImage")

sed -i -E \
  -e "s|^  version = \"[^\"]+\";|  version = \"$version\";|" \
  -e 's|^(        hash = ")[^"]+("; # update-script: aarch64-linux)$|\1'"$aarch64_hash"'\2|' \
  -e 's|^(        hash = ")[^"]+("; # update-script: x86_64-linux)$|\1'"$x86_64_hash"'\2|' \
  "$PACKAGE_NIX"

nix build "$FLAKE_DIR#orca-ide" --no-link --accept-flake-config --print-out-paths \
  | cachix push ioitiki
