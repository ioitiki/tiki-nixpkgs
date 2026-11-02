{
  lib,
  stdenv,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  wrapGAppsHook3,
  glib,
  glib-networking,
  gtk3,
  webkitgtk_4_1,
  withOAuth ? stdenv.hostPlatform.isLinux,
}:

let
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "hkdb";
    repo = "aerion";
    tag = "v${version}";
    hash = "sha256-LeYOgP1aLWBB2lRkaBOMT3LfqXk0uuQxNnkKfooqWC8=";
  };

  shimSources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-7PLMiY2Aqx33IsdMMtZd2WLsErWLZTAYV+5TcED0pUU="; # update-script: x86_64
    };
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-kATIsB2j/kloYq9WSRcTgxKSUA0neuWtF3hlyPyxWBk="; # update-script: aarch64
    };
  };

  shimSource =
    shimSources.${stdenv.hostPlatform.system}
      or (throw "aerion: OAuth shim unsupported on ${stdenv.hostPlatform.system}");

  aerion-creds = stdenv.mkDerivation {
    pname = "aerion-creds";
    inherit version;

    strictDeps = true;
    __structuredAttrs = true;

    src = fetchurl {
      url = "https://github.com/hkdb/aerion/releases/download/v${version}/flathub-build-env-v${version}-linux-${shimSource.arch}";
      inherit (shimSource) hash;
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 "$src" "$out/bin/aerion-creds"

      runHook postInstall
    '';

    meta = {
      description = "OAuth credentials shim for Aerion";
      homepage = "https://github.com/hkdb/aerion";
      license = lib.licenses.asl20;
      platforms = builtins.attrNames shimSources;
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  frontend = buildNpmPackage {
    pname = "aerion-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";

    npmDepsHash = "sha256-a4N34fzmFMZoafX1rXUyeSAm12uV7njfhRkq3KT8h+I=";

    buildPhase = ''
      runHook preBuild
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/* "$out/"
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "aerion";
  inherit version src;

  __structuredAttrs = true;

  vendorHash = "sha256-2NxgmklHScpcF4aOLPPzuVZZ2Qhmx/7SrCGnJtJ/x54=";

  subPackages = [ "." ];

  nativeBuildInputs = [
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    glib
    glib-networking
    gtk3
    webkitgtk_4_1
  ];

  tags = [
    "production"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    "desktop"
    "webkit2_41"
  ];

  preBuild = ''
    mkdir -p frontend/dist
    cp -r ${frontend}/* frontend/dist/
  '';

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    for sz in 32 48 64 128 256; do
      install -Dm644 "build/linux/icons/''${sz}x''${sz}/io.github.hkdb.Aerion.png" \
        "$out/share/icons/hicolor/''${sz}x''${sz}/apps/io.github.hkdb.Aerion.png"
    done
    install -Dm644 build/linux/icons/scalable/io.github.hkdb.Aerion.svg \
      "$out/share/icons/hicolor/scalable/apps/io.github.hkdb.Aerion.svg"
    install -Dm644 build/linux/aerion.png \
      "$out/share/pixmaps/io.github.hkdb.Aerion.png"
    install -Dm644 build/linux/aerion.desktop \
      "$out/share/applications/io.github.hkdb.Aerion.desktop"
    substituteInPlace "$out/share/applications/io.github.hkdb.Aerion.desktop" \
      --replace-fail 'TryExec=aerion' "TryExec=$out/bin/aerion" \
      --replace-fail 'Exec=aerion' "Exec=$out/bin/aerion"
    install -Dm644 build/flatpak/io.github.hkdb.Aerion.metainfo.xml \
      "$out/share/metainfo/io.github.hkdb.Aerion.metainfo.xml"
  '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    # WebKitGTK's DMABUF renderer triggers Wayland protocol error 71 on NVIDIA GPUs.
    gappsWrapperArgs+=(
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
    )
  '';

  postFixup = lib.optionalString (stdenv.hostPlatform.isLinux && withOAuth) ''
    ln -s ${aerion-creds}/bin/aerion-creds "$out/bin/aerion-creds"
  '';

  passthru = {
    inherit frontend aerion-creds;
    updateScript = ./update.sh;
  };

  meta = {
    description = "An Open Source Lightweight E-Mail Client";
    homepage = "https://github.com/hkdb/aerion";
    changelog = "https://github.com/hkdb/aerion/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "aerion";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance =
      with lib.sourceTypes;
      [ fromSource ] ++ lib.optionals withOAuth [ binaryNativeCode ];
  };
}
