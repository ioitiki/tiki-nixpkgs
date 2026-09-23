{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  wrapGAppsHook3,
  atk,
  cairo,
  fontconfig,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  libepoxy,
  libGL,
  pango,
  udev,
  xdg-user-dirs,
  zlib,
}:

let
  sources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-+7anLWHKKyasW81Ak4BjMP8b18YMDhk2wvdPg3c6VUY="; # update-script: x86_64
    };
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-mUC26FPnEVBQKesIxoeph2ryz3sCvn/VpJXYUYsVmho="; # update-script: aarch64
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "zkool: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "zkool";
  version = "6.30.0+371";

  src = fetchurl {
    url = "https://github.com/hhanh00/zkool2/releases/download/zkool-v${lib.head (lib.splitString "+" finalAttrs.version)}/zkool-${finalAttrs.version}-${source.arch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    atk
    cairo
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libepoxy
    pango
    stdenv.cc.cc.lib
    udev
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib"
    # Flutter resolves its data and plugins relative to the real executable.
    cp -r opt/zkool "$out/lib/zkool"
    cp -r usr/share "$out/share"
    substituteInPlace "$out/share/applications/zkool.desktop" \
      --replace-fail 'Exec=zkool' "Exec=$out/bin/zkool" \
      --replace-fail 'Categories=Finance;' 'Categories=Office;Finance;'

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper "$out/lib/zkool/zkool" "$out/bin/zkool" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-user-dirs ]} \
      --prefix LD_LIBRARY_PATH : "$out/lib/zkool/lib:${lib.makeLibraryPath [ libGL ]}"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Multi-account Zcash desktop wallet";
    homepage = "https://github.com/hhanh00/zkool2";
    changelog = "https://github.com/hhanh00/zkool2/releases/tag/zkool-v${lib.head (lib.splitString "+" finalAttrs.version)}";
    license = lib.licenses.mit;
    mainProgram = "zkool";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
