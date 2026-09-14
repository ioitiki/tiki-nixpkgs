{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  gst_all_1,
  gtk3,
  libsoup_3,
  pango,
  wayland,
  webkitgtk_4_1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gato";
  version = "0.6.12";

  # The upstream release is private. Download with gh outside the sandbox;
  # credentials must never become part of a derivation or the Nix store.
  src = requireFile {
    name = "GATO_${finalAttrs.version}_amd64.deb";
    hash = "sha256-xEdg6mwiDUnC4g68mM+Vi4p6k5GoLR0U0FNd14I3RK0=";
    message = ''
      GATO requires access to the private chainstarters/gato GitHub repository.
      From the tiki-nixpkgs checkout, download and import the pinned release:

        ./packages/gato/update.sh ${finalAttrs.version}

      Then run: nix build .#gato --accept-flake-config
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    dbus
    gdk-pixbuf
    glib
    # WebKit loads media elements at runtime, including appsink from base.
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gtk3
    libsoup_3
    pango
    stdenv.cc.cc.lib
    wayland
    webkitgtk_4_1
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r usr/bin usr/lib usr/share "$out/"
    # Whisper searches share/gato relative to the executable on Linux.
    mkdir -p "$out/share/gato"
    ln -s "$out/lib/GATO/_up_/_up_/whisper-runtime" "$out/share/gato/whisper-runtime"
    substituteInPlace "$out/share/applications/GATO.desktop" \
      --replace-fail 'Exec=gato-tauri' "Exec=$out/bin/gato-tauri"

    runHook postInstall
  '';

  postFixup = ''
    ln -s gato-tauri "$out/bin/gato"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "GATO desktop client for workspaces, repositories, and agents";
    homepage = "https://github.com/chainstarters/gato";
    changelog = "https://github.com/chainstarters/gato/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    mainProgram = "gato";
    platforms = [ "x86_64-linux" ];
    hydraPlatforms = [ ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
