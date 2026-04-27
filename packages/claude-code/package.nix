# NOTE: Use the following command to update the package
# ```sh
# nix-shell maintainers/scripts/update.nix --argstr commit true --arg predicate '(path: pkg: builtins.elem path [["claude-code"] ["claude-code-bin"] ["vscode-extensions" "anthropic" "claude-code"]])'
# ```
{
  lib,
  stdenv,
  buildNpmPackage,
  fetchzip,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  bubblewrap,
  procps,
  socat,
  buildFHSEnv,
}:
let
  fhs =
    { claude-code }:
    buildFHSEnv {
      name = "claude";

      targetPkgs =
        pkgs:
        (with pkgs; [
          glibc
        ]);

      runScript = "${claude-code}/bin/claude";

      passthru = {
        inherit (claude-code) pname version;
      };

      meta = claude-code.meta // {
        description = ''
          Wrapped variant of claude-code which launches in a FHS compatible environment.
        '';
      };
    };
in
buildNpmPackage (finalAttrs: {
  pname = "claude-code";
  version = "2.1.111";

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${finalAttrs.version}.tgz";
    hash = "sha256-K3qhZXVJ2DIKv7YL9f/CHkuUYnK0lkIR1wjEa+xeSCk=";
  };

  npmDepsHash = "sha256-6f68qUMnDk6tn+qypVi8bPtNrxbtcf15tHrgtlhEaK4=";

  strictDeps = true;

  # buildNpmPackage runs npmConfigHook as a postPatch hook, so the vendored
  # lockfile must be copied in prePatch for both npmDeps and the main build.
  prePatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  postPatch = ''
    # https://github.com/anthropics/claude-code/issues/15195
    substituteInPlace cli.js \
          --replace-fail '#!/bin/sh' '#!/usr/bin/env sh'
  '';

  dontNpmBuild = true;

  env.AUTHORIZED = "1";

  # `claude-code` tries to auto-update by default, this disables that functionality.
  # https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview#environment-variables
  # The DEV=true env var causes claude to crash with `TypeError: window.WebSocket is not a constructor`
  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --unset DEV \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            # claude-code uses [node-tree-kill](https://github.com/pkrumins/node-tree-kill) which requires procps's pgrep(darwin) or ps(linux)
            procps
          ]
          # the following packages are required for the sandbox to work (Linux only)
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  passthru = {
    updateScript = ./update.sh;
    fhs = fhs { claude-code = finalAttrs.finalPackage; };
  };

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      adeci
      malo
      markus1189
      omarjatoi
      xiaoxiangmoe
    ];
    mainProgram = "claude";
  };
})
