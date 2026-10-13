# Muse Code, Meta's coding agent CLI. The official installer at
# https://dev.meta.ai/install.sh installs a self-updating launcher script that
# resolves a release channel to the prebuilt binaries pinned here — run
# ./update.sh to pull the stable channel's version and hashes.
{
  lib,
  stdenv,
  fetchurl,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  sources = {
    x86_64-linux = {
      artifact = "x86-linux";
      hash = "sha256-NuPayR9WwVVyuVvlXXDun9loXNmrSfdHurR0bI18JRg="; # update-script: x86_linux
    };
    aarch64-linux = {
      artifact = "aarch64-linux";
      hash = "sha256-SNs8dGjNT0Ae/5tBX7fgzf4DUfsXMGSc6uKg92biO4U="; # update-script: aarch64_linux
    };
    x86_64-darwin = {
      artifact = "x86-macos";
      hash = "sha256-bXZtpmAaCq6L0iKUwIVJcChuG5reMAnw0CibeHWhDFg="; # update-script: x86_macos
    };
    aarch64-darwin = {
      artifact = "aarch64-macos";
      hash = "sha256-h/9aMbY+MLasBNPoKYKFUX51PBJvtvOu6ArM8oxFYvE="; # update-script: aarch64_macos
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "muse-code: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "muse-code";
  version = "1.4.7-R6101.1";

  src = fetchurl {
    # The URL ends in a query string, which is not a valid store path name.
    name = "muse-${finalAttrs.version}-${source.artifact}";
    url = "https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version=${finalAttrs.version}&file=muse-${source.artifact}";
    inherit (source) hash;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # A static executable: there is nothing to patch, and it ships stripped.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/muse"

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
    description = "Muse Code, Meta's coding agent CLI";
    homepage = "https://dev.meta.ai";
    downloadPage = "https://dev.meta.ai/install.sh";
    license = lib.licenses.unfree;
    mainProgram = "muse";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
