{
  description = "Andrew's personal Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  nixConfig = {
    extra-substituters = [ "https://ioitiki.cachix.org" ];
    extra-trusted-public-keys = [
      "ioitiki.cachix.org-1:Wvaz6A51V49iILOOeMAgcftdlbgakADidbvDszjSuNA="
    ];
  };

  outputs =
    { self, nixpkgs, ... }:
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
        kimi-cli = final.callPackage ./packages/kimi-cli/package.nix { };
        qwen-code = final.callPackage ./packages/qwen-code/package.nix { };
        flyctl = final.callPackage ./packages/flyctl/package.nix { flyctl = prev.flyctl; };
        herdr = final.callPackage ./packages/herdr/package.nix { };
        tradingagents = final.callPackage ./packages/tradingagents/package.nix { };
        warp-oss = final.callPackage ./packages/warp/package.nix { };
        zed-editor = final.callPackage ./packages/zed-editor/package.nix { };
        ib-tws = final.callPackage ./packages/ib-tws/package.nix { };
        openshell = final.callPackage ./packages/openshell/package.nix { };
        orca-ide = final.callPackage ./packages/orca/package.nix { };
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
            kimi-cli
            qwen-code
            flyctl
            herdr
            tradingagents
            warp-oss
            zed-editor
            ib-tws
            openshell
            orca-ide
            ;

          default = pkgs.codex;
        }
      );
    };
}
