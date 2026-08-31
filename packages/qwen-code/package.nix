{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  writableTmpDirAsHomeHook,
}:

let
  sources = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-IaYLC50TqQt14VHRciPm23Ve1PO/XQTHlCqo17dppNI=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-UHVuzIeGJ7AbVMlLVJE+Wp3DBh3C5ewbC2/GzdQJTIU=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "qwen-code: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "qwen-code";
  version = "0.21.7";

  src = fetchurl {
    url = "https://github.com/QwenLM/qwen-code/releases/download/v${finalAttrs.version}/qwen-code-linux-${source.arch}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = "qwen-code";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a . "$out/"

    mv "$out/bin/qwen" "$out/bin/.qwen-upstream"
    makeWrapper "$out/node/bin/node" "$out/bin/qwen" \
      --set QWEN_CODE_LAUNCHER_PATH "$out/bin/qwen" \
      --add-flags "$out/lib/cli-entry.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/qwen" --version >/dev/null

    qwenProfileBin="$TMPDIR/qwen-profile/bin"
    mkdir -p "$qwenProfileBin"
    ln -s "$out/bin/qwen" "$qwenProfileBin/qwen"
    "$qwenProfileBin/qwen" --version >/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Open-source AI coding agent for the terminal";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "qwen";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
