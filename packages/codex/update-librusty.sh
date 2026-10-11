#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnugrep gnused nix
# shellcheck shell=bash

set -eu -o pipefail

echo "librusty_v8: UPDATING"

# ASSUMES; The Cargo.lock file is located at <REPO>/codex-rs/Cargo.toml

PACKAGE_DIR=$(dirname "$(readlink --canonicalize-existing "${BASH_SOURCE[0]}")")

# Follow the version package.nix builds rather than GitHub's "latest" release,
# which can be ahead of (or unrelated to) the packaged one.
CODEX_VERSION=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";.*/\1/p' "$PACKAGE_DIR/package.nix" | head -n 1)
if [ -z "$CODEX_VERSION" ]; then
  echo "ERROR: could not read the codex version from $PACKAGE_DIR/package.nix" >&2
  exit 1
fi

CARGO_LOCK=$(curl ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} --silent --fail --location "https://github.com/openai/codex/raw/rust-v$CODEX_VERSION/codex-rs/Cargo.lock")

OUTPUT_FILE="$PACKAGE_DIR/librusty_v8.nix"
NEW_VERSION=$(echo "$CARGO_LOCK" | grep --after-context 5 'name = "v8"' | grep 'version =' | sed -E 's/version = "//;s/"//')

CURRENT_VERSION=""
if [ -f "$OUTPUT_FILE" ]; then
  CURRENT_VERSION="$(grep 'version =' "$OUTPUT_FILE" | sed -E 's/version = "//;s/"//;s/;//;s/^[[:space:]]*//')"
fi

if [ "$CURRENT_VERSION" == "$NEW_VERSION" ]; then
  echo "No update needed, $CURRENT_VERSION is already latest"
  exit 0
fi

# Codex publishes the sandbox-enabled archive/binding pairs on its own tag; see
# fetchers.nix and third_party/v8/README.md upstream.
RELEASE_BASE="https://github.com/openai/codex/releases/download/rusty-v8-v$NEW_VERSION"

TEMP_FILE="$OUTPUT_FILE.tmp"
cat >"$TEMP_FILE" <<EOF
# auto-generated file -- DO NOT EDIT!
{ fetchLibrustyV8 }:

fetchLibrustyV8 {
  version = "$NEW_VERSION";
  shas = {
    x86_64-linux = "$(nix-prefetch-url --type sha256 "$RELEASE_BASE"/librusty_v8_ptrcomp_sandbox_release_x86_64-unknown-linux-gnu.a.gz)";
    aarch64-linux = "$(nix-prefetch-url --type sha256 "$RELEASE_BASE"/librusty_v8_ptrcomp_sandbox_release_aarch64-unknown-linux-gnu.a.gz)";
  };
}
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"

OUTPUT_FILE="$PACKAGE_DIR/librusty_v8_src_binding.nix"
TEMP_FILE="$OUTPUT_FILE.tmp"
cat >"$TEMP_FILE" <<EOF
# auto-generated file -- DO NOT EDIT!
{ fetchLibrustyV8SrcBinding }:

fetchLibrustyV8SrcBinding {
  version = "$NEW_VERSION";
  shas = {
    x86_64-linux = "$(nix-prefetch-url --type sha256 "$RELEASE_BASE"/src_binding_ptrcomp_sandbox_release_x86_64-unknown-linux-gnu.rs)";
    aarch64-linux = "$(nix-prefetch-url --type sha256 "$RELEASE_BASE"/src_binding_ptrcomp_sandbox_release_aarch64-unknown-linux-gnu.rs)";
  };
}
EOF

mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "librusty_v8: UPDATE DONE"
