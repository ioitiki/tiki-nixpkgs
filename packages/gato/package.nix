{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  patchelf,
  wrapGAppsHook3,
  cairo,
  gdk-pixbuf,
  glib,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libpulseaudio,
  libsoup_3,
  onnxruntime,
  openssl,
  pipewire,
  wayland,
  webkitgtk_4_1,
  xdotool,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gato";
  version = "0.1.3-1653";

  src = fetchurl {
    url = "https://releases.gato-chainstarters.com/gato-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-uE1yNONQB7UYYUOglg+i6ceW2YxBy4/GqiCLZVR51Ww=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    gdk-pixbuf
    glib
    # WebKit loads media elements at runtime, including appsink from base.
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gtk3
    libpulseaudio
    libsoup_3
    openssl
    stdenv.cc.cc.lib
    wayland
    webkitgtk_4_1
    xdotool
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/lib/gato-desktop" \
      "$out/share/applications" \
      "$out/share/doc/gato-desktop"

    # Dioxus resolves its bundled assets relative to the real executable.
    cp gato-desktop "$out/lib/gato-desktop/gato-desktop"
    chmod 755 "$out/lib/gato-desktop/gato-desktop"
    cp -r assets "$out/lib/gato-desktop/assets"

    # Ubuntu 24.04 links libxdo.so.3 while newer nixpkgs ships xdotool 4
    # (libxdo.so.4), which exports the same xdo_new/xdo_free/xdo_send_* symbols.
    if [ ! -e "${xdotool}/lib/libxdo.so.3" ] && [ -e "${xdotool}/lib/libxdo.so.4" ]; then
      patchelf --replace-needed libxdo.so.3 libxdo.so.4 "$out/lib/gato-desktop/gato-desktop"
    fi

    for size in 16 32 48 64 128 256 512; do
      icon_dir="$out/share/icons/hicolor/''${size}x''${size}/apps"
      mkdir -p "$icon_dir"
      cp "icons/icon-''${size}.png" "$icon_dir/gato-desktop.png"
    done

    cp -r notices/* "$out/share/doc/gato-desktop/"

    cp gato-desktop.desktop "$out/share/applications/gato-desktop.desktop"
    substituteInPlace "$out/share/applications/gato-desktop.desktop" \
      --replace-fail 'Exec=gato-desktop' "Exec=$out/bin/gato-desktop"

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper "$out/lib/gato-desktop/gato-desktop" "$out/bin/gato-desktop" \
      "''${gappsWrapperArgs[@]}" \
      --set GATO_AUTOSTART_EXE "$out/bin/gato-desktop" \
      --set ORT_DYLIB_PATH "${onnxruntime}/lib/libonnxruntime.so" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}" \
      --suffix PATH : "${lib.makeBinPath [ pipewire ]}"
    ln -s gato-desktop "$out/bin/gato"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "The gato-os desktop client";
    homepage = "https://releases.gato-chainstarters.com/";
    license = lib.licenses.unfree;
    mainProgram = "gato-desktop";
    platforms = [ "x86_64-linux" ];
    hydraPlatforms = [ ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
