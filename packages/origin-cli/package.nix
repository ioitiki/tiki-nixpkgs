# Origin, Cursor's CLI. Prebuilt binaries published by the installer at
# https://downloads.cursor.com/origin/install.sh — run ./update.sh to pull the
# current stable channel's version and hashes from that script.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  sources = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-YaMw7IFhofBPNNp1082XI9hpo0fqP6YNsqxD2qkqQF0=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-21fp8amD+PTg8MoTavgB33hmInVKLsPGszyicWEqNu0=";
    };
    x86_64-darwin = {
      platform = "darwin-x64";
      hash = "sha256-5DcZhvgT6w05z4o09tbA7GMmDjET1aLOpIHSIU/wX28=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-xUAcAdt96Qy8/WNNP1M3Xn/EvWZCg9eaVOoAj7m85Yk=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "origin-cli: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "origin-cli";
  version = "2026.08.24-21-50-47-ef4ede3";

  src = fetchurl {
    url = "https://downloads.cursor.com/co/${finalAttrs.version}/${source.platform}/co.tar.gz";
    inherit (source) hash;
  };

  # The tarball is flat: just `origin` plus a legacy `co` hard link.
  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;
  # Bun-compiled single executable: stripping discards the embedded JS bundle,
  # leaving a bare Bun runtime that fails with `Script not found "completion"`.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Install only `origin`; the bundled `co` hard link is a pre-rename
    # legacy name the public installer also drops.
    install -Dm755 origin "$out/bin/origin"

    runHook postInstall
  '';

  # Patch ELF up front (instead of in autoPatchelfHook's post-fixup slot) so
  # the binary is runnable when the completions below are generated.
  dontAutoPatchelf = true;

  # `origin completion` emits a yargs completion script flavored by $SHELL.
  postFixup =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      autoPatchelf -- "$out"
    ''
    + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      export HOME="$(mktemp -d)"
      installShellCompletion --cmd origin \
        --bash <(SHELL=bash "$out/bin/origin" completion) \
        --zsh <(SHELL=zsh "$out/bin/origin" completion)
    '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Origin, Cursor's CLI for pull requests, repos, and the Cursor API";
    homepage = "https://cursor.com";
    downloadPage = "https://downloads.cursor.com/origin/install.sh";
    license = lib.licenses.unfree;
    mainProgram = "origin";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
