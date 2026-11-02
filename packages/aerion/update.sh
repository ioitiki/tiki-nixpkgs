#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#curl nixpkgs#gnused nixpkgs#jq nixpkgs#nix nixpkgs#nix-update --command bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

release=$(curl -fsSL https://api.github.com/repos/hkdb/aerion/releases/latest)
tag=$(jq -er '.tag_name' <<<"$release")
if [[ ! "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "ERROR: unrecognized Aerion release tag: $tag" >&2
  exit 1
fi
version=${BASH_REMATCH[1]}

arches=(x86_64 aarch64)
hashes=()
for arch in "${arches[@]}"; do
  name="flathub-build-env-v${version}-linux-${arch}"
  asset=$(jq -ce --arg name "$name" '
    [.assets[] | select(.name == $name)]
    | if length == 1 then .[0] else error("expected one OAuth shim asset for \($name)") end
  ' <<<"$release")
  digest=$(jq -er '.digest' <<<"$asset")
  if [[ ! "$digest" =~ ^sha256:([0-9a-f]{64})$ ]]; then
    echo "ERROR: missing or invalid SHA-256 digest for $name" >&2
    exit 1
  fi
  hash=$(nix hash convert --hash-algo sha256 --to sri "${BASH_REMATCH[1]}")
  hashes+=("$hash")
  url="https://github.com/hkdb/aerion/releases/download/$tag/$name"
  nix store prefetch-file --json --name "$name" --expected-hash "$hash" "$url" >/dev/null
done

for i in "${!arches[@]}"; do
  sed -i -E \
    "s|^(      hash = \")[^\"]+(\"; # update-script: ${arches[$i]})$|\1${hashes[$i]}\2|" \
    "$PACKAGE_NIX"
done

cd "$FLAKE_DIR"
nix-update --flake aerion --version="$version" --subpackage frontend

nix build "$FLAKE_DIR#aerion" --no-link --accept-flake-config --print-out-paths
