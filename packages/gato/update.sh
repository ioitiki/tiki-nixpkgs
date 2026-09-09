#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#cacert nixpkgs#coreutils nixpkgs#gh nixpkgs#gnused nixpkgs#jq nixpkgs#nix --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"
REPO="chainstarters/gato"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [version] (defaults to the latest release)" >&2
  exit 1
fi

release="latest"
if [[ $# -eq 1 ]]; then
  version="${1#v}"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: expected a release version such as 0.6.11" >&2
    exit 1
  fi
  release="tags/v$version"
fi

release_json=$(gh api "repos/$REPO/releases/$release")
version=$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' <<<"$release_json")
asset="GATO_${version}_amd64.deb"
digest=$(jq -er --arg asset "$asset" '
  [.assets[] | select(.name == $asset)]
  | select(length == 1) | .[0].digest
  | select(test("^sha256:[0-9a-f]{64}$"))
' <<<"$release_json")
sha256="${digest#sha256:}"

download_dir=$(mktemp -d)
trap 'rm -rf "$download_dir"' EXIT

echo "Downloading GATO $version using your GitHub login..."
gh release download "v$version" --repo "$REPO" --pattern "$asset" --dir "$download_dir"
printf '%s  %s\n' "$sha256" "$download_dir/$asset" | sha256sum --check

# Import even when the version is unchanged: requireFile needs this on each
# machine, and the source may have been garbage-collected since the last build.
nix-store --add-fixed sha256 "$download_dir/$asset"
hash=$(nix hash convert --hash-algo sha256 --to sri "$sha256")

sed -i -E \
  -e "s|^  version = \"[^\"]+\";|  version = \"$version\";|" \
  -e "s|^    hash = \"[^\"]+\";|    hash = \"$hash\";|" \
  "$PACKAGE_NIX"

echo "GATO $version is ready. Build with: nix build .#gato --accept-flake-config"
