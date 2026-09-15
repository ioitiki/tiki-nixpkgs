{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  gitMinimal,
  ripgrep,
  xdg-utils,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  sources = {
    x86_64-linux = {
      # The baseline binary also runs on CPUs without AVX2.
      platform = "linux/x64-baseline";
      hash = "sha256-H4o8e3K/Xnw34qwMx6ckOp54VTZDjQpLo0c7AYbOITQ="; # update-script: linux/x64-baseline
    };
    aarch64-linux = {
      platform = "linux/arm64";
      hash = "sha256-8QM4Z5JRt87ikY9z9jFiarpKf/0Oqbusg68Nu6zfOj0="; # update-script: linux/arm64
    };
    aarch64-darwin = {
      platform = "darwin/arm64";
      hash = "sha256-ob+Xx3PEO8Cwn/3qaXtXtm3rNy9l2pP3eiO/IX2DzhY="; # update-script: darwin/arm64
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "factory: unsupported platform ${stdenv.hostPlatform.system}");
  runtimePackages = [
    gitMinimal
    ripgrep
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [ xdg-utils ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "factory";
  version = "0.219.0";

  src = fetchurl {
    url = "https://downloads.factory.ai/factory-cli/releases/${finalAttrs.version}/${source.platform}/droid";
    inherit (source) hash;
  };

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Stripping a Bun executable can discard its embedded JavaScript bundle.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/factory/droid"
    makeWrapper "$out/libexec/factory/droid" "$out/bin/droid" \
      --set FACTORY_DROID_AUTO_UPDATE_ENABLED false \
      --prefix PATH : ${lib.makeBinPath runtimePackages}

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Factory's Droid coding agent CLI";
    homepage = "https://factory.ai";
    downloadPage = "https://app.factory.ai/cli";
    license = lib.licenses.unfree;
    mainProgram = "droid";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
