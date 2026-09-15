# Personal Packages

Reusable Nix package flake for Andrew's machines.

## Build

```bash
nix build .#codex --accept-flake-config
```

## Push to Cachix

```bash
nix build --no-link --print-out-paths .#codex --accept-flake-config | cachix push ioitiki
```

## Install on another machine

```bash
cachix use ioitiki
nix profile install github:ioitiki/personal-packages#codex --accept-flake-config
```

If the GitHub repository uses a different owner or name, replace
`github:ioitiki/personal-packages` with the published flake URL.

## Factory CLI

The `factory` package provides Factory's `droid` command:

```bash
nix run .#factory --accept-flake-config -- --version
nix run .#factory --accept-flake-config
```

Run `./packages/factory/update.sh` to pin the latest official release and
checksums, then build it. Droid's built-in updater is disabled so Nix manages
the installed version. The package supports x86-64 Linux, ARM64 Linux, and
Apple Silicon macOS.

## GATO desktop (x86-64 Linux)

GATO is packaged from the private `chainstarters/gato` release. With a `gh`
login that can access that repository, import the release and build it:

```bash
./packages/gato/update.sh 0.6.12
nix build .#gato --accept-flake-config
nix run .#gato --accept-flake-config
```

Run `./packages/gato/update.sh` without a version to update to the latest
release. The script verifies GitHub's SHA-256 digest and imports the download
into the local Nix store; it also works when the pinned version is unchanged.
Credentials stay outside Nix builds. Repeat the import on each build machine.

The package includes the desktop entry, icons, Whisper executable, and speech
model. Version 0.6.11 connects to GATO's dev backend; Workspaces can be enabled
under Sidebar navigation in Settings.
