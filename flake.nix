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
        "aarch64-darwin"
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
        glm-code = final.callPackage ./packages/glm-code/package.nix { };
        flyctl = final.callPackage ./packages/flyctl/package.nix { flyctl = prev.flyctl; };
        herdr = final.callPackage ./packages/herdr/package.nix { };
        tradingagents = final.callPackage ./packages/tradingagents/package.nix { };
        warp-oss = final.callPackage ./packages/warp/package.nix { };
        zed-editor = final.callPackage ./packages/zed-editor/package.nix { };
        ib-tws = final.callPackage ./packages/ib-tws/package.nix { };
        openshell = final.callPackage ./packages/openshell/package.nix { };
        orca-ide = final.callPackage ./packages/orca/package.nix { };
        origin-cli = final.callPackage ./packages/origin-cli/package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
          inherit (nixpkgs) lib;
          inherit (pkgs.stdenv.hostPlatform) isLinux;
          isX86Linux = system == "x86_64-linux";
        in
        # Packages are grouped by the platforms their upstreams actually ship
        # for. Exposing one on a system it cannot evaluate on breaks `nix flake
        # check` and the bare `default` attribute for every package beside it.
        {
          inherit (pkgs)
            claude-code
            deepagents
            kimi-cli
            glm-code
            flyctl
            herdr
            tradingagents
            zed-editor
            origin-cli
            ;

          default = if isLinux then pkgs.codex else pkgs.glm-code;
        }
        # Linux-only upstreams.
        // lib.optionalAttrs isLinux {
          inherit (pkgs)
            codex
            qwen-code
            ib-tws
            orca-ide
            ;
        }
        # Published for x86_64-linux alone; these already failed to evaluate on
        # aarch64-linux before Darwin was added.
        // lib.optionalAttrs isX86Linux {
          inherit (pkgs)
            warp-oss
            openshell
            ;
        }
      );
    };
}
