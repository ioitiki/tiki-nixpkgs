#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

# Get latest version from GitHub releases (excluding pre-releases and special versions)
echo "Fetching latest version from GitHub..."
version=$(curl -s "https://api.github.com/repos/zed-industries/zed/releases" | \
    jq -r '[.[] | select(.prerelease == false) | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))] | first | .tag_name' | \
    sed 's/^v//')

if [[ -z "$version" || "$version" == "null" ]]; then
    echo "Failed to fetch latest version"
    exit 1
fi
echo "Latest version: $version"

# Get current version from package.nix
current_version=$(grep -oP 'version = "\K[^"]+' "$PACKAGE_NIX" | head -1)
echo "Current version: $current_version"

if [[ "$version" == "$current_version" ]]; then
    echo "Already at latest version, nothing to do."
    exit 0
fi

# Update version in package.nix
echo "Updating version in package.nix..."
sed -i "s/version = \"[^\"]*\"/version = \"$version\"/" "$PACKAGE_NIX"

# Clear both hashes (src hash and cargoHash)
echo "Clearing hashes..."
# Clear the fetchFromGitHub hash
sed -i 's/hash = "sha256-[^"]*"/hash = ""/' "$PACKAGE_NIX"
# Clear the cargoHash
sed -i 's/cargoHash = "sha256-[^"]*"/cargoHash = ""/' "$PACKAGE_NIX"

# First build attempt - get src hash
echo "Building package to get src hash..."
src_hash=$(nix build "$FLAKE_DIR#zed-editor" --no-link 2>&1 | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1) || true

if [[ -n "$src_hash" ]]; then
    echo "Got src hash: $src_hash"
    sed -i "s|hash = \"\"|hash = \"$src_hash\"|" "$PACKAGE_NIX"
else
    echo "Failed to get src hash"
    exit 1
fi

# Second build attempt - get cargoHash
echo "Building package to get cargoHash..."
cargo_hash=$(nix build "$FLAKE_DIR#zed-editor" --no-link 2>&1 | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1) || true

if [[ -n "$cargo_hash" ]]; then
    echo "Got cargo hash: $cargo_hash"
    sed -i "s|cargoHash = \"\"|cargoHash = \"$cargo_hash\"|" "$PACKAGE_NIX"
else
    echo "Failed to get cargo hash"
    exit 1
fi

echo "Update complete! zed-editor updated to version $version"
