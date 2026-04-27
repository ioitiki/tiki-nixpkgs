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
