{
  alsa-lib,
  appimageTools,
  atk,
  at-spi2-atk,
  at-spi2-core,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  expat,
  fetchurl,
  gdk-pixbuf,
  glib,
  gobject-introspection,
  harfbuzz,
  gtk3,
  libGL,
  libdrm,
  libgbm,
  lib,
  libnotify,
  libsecret,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  libxcb,
  makeWrapper,
  nspr,
  nss,
  pango,
  python3,
  stdenv,
  systemd,
  wayland,
  wl-clipboard,
  xclip,
  xdotool,
  xorg-server,
}:

let
  pname = "orca-ide";
  version = "1.4.167";

  source =
    {
      aarch64-linux = {
        asset = "orca-linux-arm64.AppImage";
        hash = "sha512-C6xVOJ0Ktq0g8ajYI8tDLEN2a0Zx5bTsBV8GCDEgXuGcdihuOCxLP059dZorNOwGbrGyxMBuI3gEgSRs6S0JzQ=="; # update-script: aarch64-linux
      };
      x86_64-linux = {
        asset = "orca-linux.AppImage";
        hash = "sha512-rITr7NODzoeaY8y3yVCu+lqtczKnQMWAu8mowS7Y/2l6LwhptlCOOB+5J17lQwqNVALay1tqaXgfDnDnJBsIJQ=="; # update-script: x86_64-linux
      };
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

  typelibDependencies = map (lib.getOutput "out") [
    at-spi2-core
    gdk-pixbuf
    glib
    gobject-introspection.unwrapped
    harfbuzz
    gtk3
    pango
  ];

  runtimeDependencies = typelibDependencies ++ [
    alsa-lib
    atk
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    libGL
    libdrm
    libgbm
    libnotify
    libsecret
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxtst
    libxcb
    nspr
    nss
    (python3.withPackages (pythonPackages: [ pythonPackages.pygobject3 ]))
    stdenv.cc.cc.lib
    systemd
    wayland
    wl-clipboard
    xclip
    xdotool
    xorg-server
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  # appimageTools.wrapType2 uses buildFHSEnv, whose Bubblewrap launcher sets
  # PR_SET_NO_NEW_PRIVS. Orca's daemon and every terminal it creates inherit
  # that flag, preventing setuid programs such as sudo from elevating. Patch
  # the extracted AppImage in place so Orca runs directly on NixOS instead.
  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = runtimeDependencies;

  # Chromium dlopens GL/Wayland/etc. libraries that never appear in DT_NEEDED,
  # so autoPatchelf must be told to append them to every binary's RUNPATH.
  # Baking them into RUNPATH instead of exporting LD_LIBRARY_PATH from the
  # wrapper keeps Orca's pinned libraries out of the environment of every
  # terminal and agent the daemon spawns.
  inherit runtimeDependencies;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/orca $out/opt/orca $out/share/applications
    cp -r ${appimageContents}/. $out/opt/orca/
    chmod -R u+w $out/opt/orca
    # Apply the guarded renderer customizations: keep the right sidebar out of
    # the workspace flex flow and show each worktree card's PR number above its
    # colored PR status icon.
    ${python3}/bin/python3 ${./patch-floating-right-sidebar.py} \
      $out/opt/orca/resources/app.asar
    # These legacy AppRun compatibility libraries target GTK 2 and are not
    # used when invoking the Electron binary directly.
    rm -rf $out/opt/orca/usr/lib

    cp $out/opt/orca/orca-ide.desktop \
      $out/share/applications/orca-ide.desktop
    cp -r $out/opt/orca/usr/share/icons $out/share/

    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-fail 'Exec=AppRun' "Exec=$out/libexec/orca/orca-ide-gui"

    # Keep desktop launches on the Electron binary while public CLI commands
    # use the dedicated binary under resources/bin. Bare `orca-ide` remains a
    # convenient desktop launch; with arguments it follows Orca's Linux CLI
    # resolver contract and behaves exactly like `orca`.
    makeWrapper $out/opt/orca/orca-ide $out/libexec/orca/orca-ide-gui \
      --run 'export ORCA_NODE_OPTIONS="''${NODE_OPTIONS-}"' \
      --run 'export ORCA_NODE_REPL_EXTERNAL_MODULE="''${NODE_REPL_EXTERNAL_MODULE-}"' \
      --unset NODE_OPTIONS \
      --unset NODE_REPL_EXTERNAL_MODULE \
      --set APPDIR $out/opt/orca \
      --prefix PATH : $out/opt/orca:$out/opt/orca/usr/sbin \
      --prefix XDG_DATA_DIRS : $out/opt/orca/usr/share \
      --prefix GSETTINGS_SCHEMA_DIR : $out/opt/orca/usr/share/glib-2.0/schemas \
      --prefix GI_TYPELIB_PATH : ${lib.makeSearchPath "lib/girepository-1.0" typelibDependencies} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    makeWrapper $out/opt/orca/resources/bin/orca-ide $out/bin/orca
    makeWrapper $out/opt/orca/resources/bin/orca-ide $out/bin/orca-ide \
      --run "if [ \"\$#\" -eq 0 ]; then exec \"$out/libexec/orca/orca-ide-gui\"; fi"

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "AI orchestrator for running coding agents in parallel";
    homepage = "https://github.com/stablyai/orca";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "orca-ide";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
