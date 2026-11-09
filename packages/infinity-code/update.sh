#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#curl nixpkgs#gnused nixpkgs#jq nixpkgs#nix nixpkgs#prefetch-npm-deps --command bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

commit_json=$(curl -fsSL https://api.github.com/repos/hydro-project/infinity/commits/main)
rev=$(jq -er '.sha' <<<"$commit_json")

cargo_toml=$(curl -fsSL "https://raw.githubusercontent.com/hydro-project/infinity/${rev}/crates/infinity-agent-cli/Cargo.toml")
version=$(sed -nE 's/^version = "([^"]+)"/\1/p' <<<"$cargo_toml" | head -n1)
if [[ -z "$version" ]]; then
  echo "ERROR: could not determine infinity-agent-cli version" >&2
  exit 1
fi

current_rev=$(sed -nE 's/^  rev = "([^"]+)";/\1/p' "$PACKAGE_NIX")
if [[ "$rev" == "$current_rev" ]]; then
  echo "infinity-code is already at ${version} (${rev})."
  exit 0
fi

src_prefetch=$(nix-prefetch-url --unpack --print-path "https://github.com/hydro-project/infinity/archive/${rev}.tar.gz")
src_hash_raw=$(head -n1 <<<"$src_prefetch")
src_path=$(tail -n1 <<<"$src_prefetch")
src_hash=$(nix hash convert --hash-algo sha256 --to sri "$src_hash_raw")

ui_npm_hash=$(prefetch-npm-deps "$src_path/infinity-ui/package-lock.json")
web_npm_hash=$(prefetch-npm-deps "$src_path/infinity-web/package-lock.json")

cargo_hash=$(
  nix build --impure --expr "
    let
      pkgs = import (builtins.getFlake (toString $FLAKE_DIR)).inputs.nixpkgs { system = builtins.currentSystem; };
      src = builtins.storePath \"$src_path\";
    in
    pkgs.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = pkgs.lib.fakeHash;
    }
  " 2>&1 | sed -nE 's/.*got:[[:space:]]*(sha256-[A-Za-z0-9+/=]+).*/\1/p' | tail -n1
)

if [[ -z "$cargo_hash" ]]; then
  echo "ERROR: failed to compute cargoHash for infinity-code" >&2
  exit 1
fi

sed -i -E \
  -e "s|^  version = \"[^\"]+\";|  version = \"$version\";|" \
  -e "s|^  rev = \"[^\"]+\";|  rev = \"$rev\";|" \
  -e "0,/hash = \"sha256-[^\"]+\";/s||hash = \"$src_hash\";|" \
  -e "0,/npmDepsHash = \"sha256-[^\"]+\";/s||npmDepsHash = \"$ui_npm_hash\";|" \
  -e "s|^    npmDepsHash = \"[^\"]+\";|    npmDepsHash = \"$web_npm_hash\";|" \
  -e "s|^  cargoHash = \"[^\"]+\";|  cargoHash = \"$cargo_hash\";|" \
  "$PACKAGE_NIX"

# Restore uiNodeModules npmDepsHash after the second replacement
sed -i -E \
  "/pname = \"infinity-ui-node-modules\";/,/dontNpmBuild = true;/s|npmDepsHash = \"[^\"]+\";|npmDepsHash = \"$ui_npm_hash\";|" \
  "$PACKAGE_NIX"

echo "Updated infinity-code to $version ($rev)."
nix build "$FLAKE_DIR#infinity-code" --no-link --accept-flake-config --print-out-paths
