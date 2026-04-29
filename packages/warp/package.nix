{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  alsa-lib,
  cmake,
  expat,
  fontconfig,
  freetype,
  libglvnd,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  makeBinaryWrapper,
  openssl,
  pkg-config,
  protobuf,
  vulkan-loader,
  wayland,
  xdg-utils,
  zlib,
}:

let
  warpProtoApis = fetchFromGitHub {
    owner = "warpdotdev";
    repo = "warp-proto-apis";
    rev = "78a78f21a75432bf0141e396fb318bf1694e47f0";
    hash = "sha256-8bB/tCLIzRCofMK1rYCe8bizUr1U4A6f6uVeckJJKI4=";
  };

  warpWorkflows = fetchFromGitHub {
    owner = "warpdotdev";
    repo = "workflows";
    rev = "793a98ddda6ef19682aed66364faebd2829f0e01";
    hash = "sha256-ICgkxlUUIfyhr0agZEk3KtGHX0uNRlRCKtz0iF2jd7o=";
  };

  runtimeLibs = [
    alsa-lib
    fontconfig
    freetype
    libglvnd
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    vulkan-loader
    wayland
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "warp-oss";
  version = "0-unstable-2026-04-28";

  src = fetchFromGitHub {
    owner = "warpdotdev";
    repo = "warp";
    rev = "d0f045c01bacbd845a631d07da30f277cfd2b98d";
    hash = "sha256-ChtFrQGd4ha2DFb/gv8lIy0tyygoo3eoaY2hjL6dBIo=";
  };

  cargoHash = "sha256-TzYSC82HVRhCxBHLmHw8BIZ4hJKCZfp+s/mfbeAjdQ4=";

  nativeBuildInputs = [
    cmake
    makeBinaryWrapper
    pkg-config
    protobuf
    rustPlatform.bindgenHook
  ];

  buildInputs = runtimeLibs ++ [
    expat
    openssl
    zlib
  ];

  postPatch = ''
    for dep in "$cargoDepsCopy"/source-git-*/warp_multi_agent_api-*; do
      mkdir -p "$dep/protos"
      cp ${warpProtoApis}/apis/multi_agent/v1/*.proto "$dep/protos/"
      substituteInPlace "$dep/build.rs" \
        --replace-fail \
          'let proto_path = manifest_dir.parent().unwrap().parent().unwrap();' \
          'let proto_path = manifest_dir.join("protos");'
    done

    for dep in "$cargoDepsCopy"/source-git-*/warp-workflows-0.1.0; do
      mkdir -p "$dep/specs"
      cp -R ${warpWorkflows}/specs/. "$dep/specs/"
      substituteInPlace "$dep/build.rs" \
        --replace-fail '../specs' 'specs'
    done
  '';

  cargoBuildFlags = [
    "--package=warp"
    "--bin=warp-oss"
    "--bin=generate_settings_schema"
    "--features=release_bundle,gui,nld_improvements"
  ];

  env = {
    APPIMAGE_NAME = "WarpOss-${stdenv.hostPlatform.parsed.cpu.name}.AppImage";
    GIT_RELEASE_TAG = finalAttrs.version;
  };

  doCheck = false;

  installPhase = ''
    runHook preInstall

    releaseTarget="target/${stdenv.hostPlatform.rust.cargoShortTarget}/release"
    installRoot="$out/libexec/warp"

    install -Dm755 "$releaseTarget/warp-oss" "$installRoot/warp-oss"

    mkdir -p "$installRoot/resources"
    cp -R resources/bundled "$installRoot/resources/bundled"
    "$releaseTarget/generate_settings_schema" --channel stable "$installRoot/resources/settings_schema.json"

    install -Dm644 app/channels/oss/dev.warp.WarpOss.desktop \
      "$out/share/applications/dev.warp.WarpOss.desktop"
    install -Dm644 app/channels/oss/icon/no-padding/512x512.png \
      "$out/share/icons/hicolor/512x512/apps/dev.warp.WarpOss.png"

    makeWrapper "$installRoot/warp-oss" "$out/bin/warp-oss" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}

    runHook postInstall
  '';

  meta = {
    description = "Open-source agentic development environment from Warp";
    homepage = "https://github.com/warpdotdev/warp";
    license = with lib.licenses; [
      agpl3Only
      asl20
      mit
    ];
    mainProgram = "warp-oss";
    platforms = [ "x86_64-linux" ];
  };
})
