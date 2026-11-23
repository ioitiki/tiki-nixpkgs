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

## Zkool desktop (Linux)

The `zkool` package provides the Zcash wallet's graphical desktop app,
including its application-menu entry and icons:

```bash
nix build .#zkool --accept-flake-config
nix run .#zkool --accept-flake-config
```

It packages the official Debian releases for x86-64 and ARM64 Linux.
Run `./packages/zkool/update.sh` to verify the latest release artifacts against
GitHub's SHA-256 digests, update the pinned version and hashes, and build it.

## thinkorswim desktop (x86-64 Linux)

```bash
nix build .#thinkorswim --accept-flake-config
nix run .#thinkorswim --accept-flake-config
```

The package pins Schwab's Linux bootstrap installer and supplies Zulu Java 21
and the native libraries through an FHS environment. On first launch it
installs into `~/thinkorswim`; Schwab's updater maintains that writable
installation. Browser settings live in `~/.thinkorswim`. The Nix package
version describes the bootstrap installer, not the automatically updated app.

Chromium's sandbox remains enabled. The host must allow unprivileged user
namespaces (`unshare -Ur true`), which Flatpak blocks for this application.
This FHS environment supplies a Linux filesystem layout; it is not an
application security sandbox.

To refresh the bootstrap installer, inspect the official download and update
its SHA-256 hash in `packages/thinkorswim/package.nix`. Rebuilding the wrapper
does not replace an existing writable installation or its settings.

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

## Muse Code

The `muse-code` package provides Meta's `muse` coding agent:

```bash
nix run .#muse-code --accept-flake-config -- --version
nix run .#muse-code --accept-flake-config
```

Run `./packages/muse-code/update.sh` to pin the stable channel's current
release and checksums, then build it. The package installs the release binary
itself rather than Meta's self-updating launcher script, so Nix manages the
installed version. The package supports x86-64 Linux, ARM64 Linux, and Apple
Silicon macOS.

## GATO desktop (x86-64 Linux)

GATO (`gato-desktop`) is packaged from the public `gato-os` Linux release
tarball at `https://releases.gato-chainstarters.com/`:

```bash
./packages/gato/update.sh
nix build .#gato --accept-flake-config
nix run .#gato --accept-flake-config
```

Run `./packages/gato/update.sh` (or pass `<version>-<build>`, e.g. `0.1.3-1649`)
to read the release record, verify the tarball's SHA-256, update `package.nix`,
and build it. The wrapper provides GTK/WebKitGTK runtime paths, nixpkgs'
ONNX Runtime (`ORT_DYLIB_PATH`), `libayatana-appindicator` for the system tray,
`pipewire` (`pw-record`) for meeting capture, and `GATO_AUTOSTART_EXE` so login
autostart invokes the wrapped binary.

## Aerion desktop (Linux)

The `aerion` package builds the [Aerion](https://github.com/hkdb/aerion) email
client from source (Wails + Svelte) and bundles upstream's OAuth credentials
shim by default so Gmail and Microsoft 365 OAuth work out of the box:

```bash
nix build .#aerion --accept-flake-config
nix run .#aerion --accept-flake-config
```

Run `./packages/aerion/update.sh` to update the pinned release version, frontend
npm dependencies hash, Go vendor hash, and OAuth shim hashes for `x86_64-linux`
and `aarch64-linux`.

## Infinity Code

The `infinity-code` package builds [Infinity Code](https://infinity.hydro.run/docs/infinity-code/overview/)
from [`hydro-project/infinity`](https://github.com/hydro-project/infinity), including:
- `infinity` (`infinity-agent-cli`, with `--features bundled-web` for the local web UI on `http://127.0.0.1:8080`)
- `infinity-daemon`
- `infinity-provider-bedrock` (AWS Bedrock model provider)
- `sandbox-local`, `rap-steering-server`, and `rap-github-event-poller` RAP servers

```bash
nix build .#infinity-code --accept-flake-config
nix run .#infinity-code --accept-flake-config
```

On first launch, the wrapper seeds `~/.infinity/providers.json` (`infinity-provider-bedrock`)
and `~/.infinity/rap.json` (`sandbox-local`) if they do not exist yet, and puts
`ripgrep`, `git`, `jj` (`jujutsu`), and `bwrap` (`bubblewrap` on Linux) on `PATH`.
Run `./packages/infinity-code/update.sh` to update to the latest upstream commit.
