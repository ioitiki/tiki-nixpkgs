#!/usr/bin/env nix
#!nix shell nixpkgs#cacert nixpkgs#nix nixpkgs#gnused nixpkgs#coreutils nixpkgs#bash nixpkgs#curl nixpkgs#cachix --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

# The public installer has the stable channel's version and per-platform
# SHA256s baked in — it is the release manifest.
installer="$(curl -fsSL https://downloads.cursor.com/origin/install.sh)"
stable_block="$(printf '%s\n' "$installer" | sed -n '/^stable)$/,/^  esac$/p')"

version="$(printf '%s\n' "$stable_block" | sed -n 's/^  version="\(.*\)"$/\1/p')"
if [ -z "$version" ]; then
  echo "ERROR: could not parse stable version from install.sh" >&2
  exit 1
fi

current="$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$PACKAGE_NIX")"
if [ "$version" = "$current" ]; then
  echo "origin-cli is already at $version"
  exit 0
fi
echo "Updating origin-cli: $current -> $version"

sha_for() {
  printf '%s\n' "$stable_block" \
    | sed -n "/^  $1)\$/,/;;/p" \
    | sed -n 's/^    sha="\(.*\)"$/\1/p'
}

sed -i "s|^  version = \".*\";$|  version = \"$version\";|" "$PACKAGE_NIX"

for platform in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
  sha="$(sha_for "$platform")"
  if [ -z "$sha" ]; then
    echo "ERROR: no sha for $platform in install.sh" >&2
    exit 1
  fi
  sri="$(nix hash convert --hash-algo sha256 --to sri "$sha")"
  sed -i "/platform = \"$platform\";/{n;s|hash = \".*\";|hash = \"$sri\";|;}" "$PACKAGE_NIX"
done

nix build "$FLAKE_DIR#origin-cli" --no-link --accept-flake-config --print-out-paths | cachix push ioitiki
