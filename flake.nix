{
  description = "Andrew's personal Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    npm-lockfile-fix = {
      url = "github:jeslie0/npm-lockfile-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://ioitiki.cachix.org" ];
    extra-trusted-public-keys = [
      "ioitiki.cachix.org-1:Wvaz6A51V49iILOOeMAgcftdlbgakADidbvDszjSuNA="
    ];
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = final: prev: {
        claude-code = final.callPackage ./packages/claude-code/package.nix { };
        codex = final.callPackage ./packages/codex/package.nix { };
        deepagents = final.callPackage ./packages/deepagents/package.nix { };
        hermes-agent = final.callPackage ./packages/hermes-agent/package.nix {
          inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
          npm-lockfile-fix = inputs.npm-lockfile-fix.packages.${final.stdenv.hostPlatform.system}.default;
        };
        kimi-cli = final.callPackage ./packages/kimi-cli/package.nix { };
        flyctl = final.callPackage ./packages/flyctl/package.nix { flyctl = prev.flyctl; };
        tradingagents = final.callPackage ./packages/tradingagents/package.nix { };
        warp-oss = final.callPackage ./packages/warp/package.nix { };
        zed-editor = final.callPackage ./packages/zed-editor/package.nix { };
        ib-tws = final.callPackage ./packages/ib-tws/package.nix { };
        openshell = final.callPackage ./packages/openshell/package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs)
            claude-code
            codex
            deepagents
            hermes-agent
            kimi-cli
            flyctl
            tradingagents
            warp-oss
            zed-editor
            ib-tws
            openshell
            ;

          default = pkgs.codex;
        }
      );
    };
}
