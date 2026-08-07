#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#cachix nixpkgs#coreutils nixpkgs#curl nixpkgs#gnugrep nixpkgs#gnused nixpkgs#jq nixpkgs#nix --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

usage() {
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 1.4.150" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

version=${1#v}
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Version must be a stable Orca version such as 1.4.150." >&2
  exit 2
fi

current_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$PACKAGE_NIX")
if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Could not determine the current Orca version from $PACKAGE_NIX." >&2
  exit 1
fi

if [[ "$version" == "$current_version" ]]; then
  echo "ERROR: Orca is already at version $version." >&2
  exit 2
fi

lowest_version=$(printf '%s\n%s\n' "$version" "$current_version" | sort -V | head -n 1)
if [[ "$lowest_version" != "$version" ]]; then
  echo "ERROR: Target $version is newer than current version $current_version; use update.sh instead." >&2
  exit 2
fi

echo "Current Orca version: $current_version"
echo "Downgrade target: $version"

release_json=$(curl -fsSL "https://api.github.com/repos/stablyai/orca/releases/tags/v${version}")
if ! jq -e --arg tag "v${version}" \
  '.tag_name == $tag and (.draft | not) and (.prerelease | not)' \
  <<<"$release_json" >/dev/null; then
  echo "ERROR: v$version is not a published stable Orca release." >&2
  exit 1
fi

release_has_asset() {
  local asset=$1

  if ! jq -e --arg asset "$asset" '.assets | any(.name == $asset)' \
    <<<"$release_json" >/dev/null; then
    echo "ERROR: Release v$version does not contain $asset." >&2
    exit 1
  fi
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
    echo "ERROR: Invalid metadata in $metadata_asset." >&2
    exit 1
  fi

  printf 'sha512-%s' "$hash"
}

x86_64_hash=$(release_hash "latest-linux.yml" "orca-linux.AppImage")
aarch64_hash=$(release_hash "latest-linux-arm64.yml" "orca-linux-arm64.AppImage")

package_backup=$(mktemp)
cp --preserve=mode "$PACKAGE_NIX" "$package_backup"

restore_on_failure() {
  local rc=$?
  trap - EXIT

  if [[ $rc -ne 0 ]]; then
    cp --preserve=mode "$package_backup" "$PACKAGE_NIX"
    echo "ERROR: Downgrade failed; restored $PACKAGE_NIX." >&2
  fi

  rm -f "$package_backup"
  exit "$rc"
}
trap restore_on_failure EXIT

sed -i -E \
  -e "s|^  version = \"[^\"]+\";|  version = \"$version\";|" \
  -e 's|^(        hash = ")[^"]+("; # update-script: aarch64-linux)$|\1'"$aarch64_hash"'\2|' \
  -e 's|^(        hash = ")[^"]+("; # update-script: x86_64-linux)$|\1'"$x86_64_hash"'\2|' \
  "$PACKAGE_NIX"

if ! grep -Fq "  version = \"$version\";" "$PACKAGE_NIX" \
  || ! grep -Fq "        hash = \"$aarch64_hash\"; # update-script: aarch64-linux" "$PACKAGE_NIX" \
  || ! grep -Fq "        hash = \"$x86_64_hash\"; # update-script: x86_64-linux" "$PACKAGE_NIX"; then
  echo "ERROR: Failed to rewrite all Orca version and hash fields." >&2
  exit 1
fi

nix build "$FLAKE_DIR#orca-ide" --no-link --accept-flake-config --print-out-paths \
  | cachix push ioitiki

echo "Downgraded Orca from $current_version to $version."
