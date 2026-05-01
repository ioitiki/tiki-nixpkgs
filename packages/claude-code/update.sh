#!/usr/bin/env nix
#!nix shell nixpkgs#cacert nixpkgs#nodejs nixpkgs#git nixpkgs#nix-update nixpkgs#nix nixpkgs#gnused nixpkgs#findutils nixpkgs#coreutils nixpkgs#bash nixpkgs#home-manager nixpkgs#curl nixpkgs#gnutar nixpkgs#gzip nixpkgs#jq --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$FLAKE_DIR"

version=$(npm view @anthropic-ai/claude-code version)

# Update version and src hash via nix-update (skip lockfile/deps, we handle them ourselves)
AUTHORIZED=1 NIXPKGS_ALLOW_UNFREE=1 nix-update --src-only --flake claude-code --version="$version"

# Regenerate package-lock.json from the new source
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
curl -sL "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz" | tar xz -C "$tmpdir"
(cd "$tmpdir/package" && npm install --package-lock-only --ignore-scripts)
cp "$tmpdir/package/package-lock.json" "$SCRIPT_DIR/package-lock.json"
echo "Regenerated package-lock.json for version $version"

# Update npmDepsHash: use fakeHash to force a build failure, then extract the correct hash
sed -i 's|npmDepsHash = "sha256-[^"]*";|npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";|' "$SCRIPT_DIR/package.nix"
new_hash=$( (nix build .#claude-code --no-link 2>&1 || true) | sed -nE 's/.*got: *(sha256-[A-Za-z0-9+/=-]+).*/\1/p' | tail -1 )
if [ -n "$new_hash" ]; then
  echo "Updating npmDepsHash to $new_hash"
  sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$new_hash\";|" "$SCRIPT_DIR/package.nix"
else
  echo "ERROR: Could not determine npmDepsHash" >&2
  exit 1
fi

nix build "$FLAKE_DIR#claude-code" --no-link --accept-flake-config --print-out-paths | cachix push ioitiki
