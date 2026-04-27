#!/usr/bin/env nix
#!nix shell nixpkgs#cacert nixpkgs#git nixpkgs#nix-update nixpkgs#nix nixpkgs#gnused nixpkgs#coreutils nixpkgs#bash nixpkgs#home-manager nixpkgs#curl nixpkgs#jq --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$FLAKE_DIR"

# Get latest stable rust-v* release version from GitHub (skip pre-releases and alpha/beta/rc)
version=$(curl -s "https://api.github.com/repos/openai/codex/releases" \
  | jq -r '[.[] | select(.prerelease | not) | select(.tag_name | test("^rust-v\\d+\\.\\d+\\.\\d+$")) | .tag_name][0]' \
  | sed 's/^rust-v//')

if [ -z "$version" ]; then
  echo "ERROR: Could not determine latest codex version" >&2
  exit 1
fi

echo "Latest codex version: $version"

# nix-update handles version, src hash, and cargoHash for Rust packages
nix-update --flake codex --version="$version" --version-regex '^rust-v(\d+\.\d+\.\d+)$'

nix build "$FLAKE_DIR#codex" --no-link --accept-flake-config
