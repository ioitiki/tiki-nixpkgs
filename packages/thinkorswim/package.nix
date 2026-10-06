{
  lib,
  buildFHSEnv,
  fetchurl,
  makeDesktopItem,
  writeShellApplication,
  zulu21,
}:

let
  # This is the bootstrap installer version. Schwab updates the writable
  # application on launch independently of this Nix package.
  version = "1991.3.0";
  installer = fetchurl {
    url = "https://tosmediaserver.schwab.com/installer/InstFiles/thinkorswim_installer.sh";
    hash = "sha256-N/hG8vKCb2NJcNA+t3VV3OWPTMPuvEIS9UghStExC+A=";
  };
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/flathub/com.tdameritrade.ThinkOrSwim/59147a9de25d3b35aae160f4570dcf548efbadec/com.tdameritrade.ThinkOrSwim.png";
    hash = "sha256-Vuq/dPBoRXCC05l+5YDeC3L7Hg2gKOY+QDOXlsw3AdY=";
  };
  desktopItem = makeDesktopItem {
    name = "thinkorswim";
    desktopName = "thinkorswim";
    comment = "Schwab trading platform";
    exec = "thinkorswim";
    icon = "thinkorswim";
    categories = [
      "Office"
      "Finance"
    ];
  };
  launcher = writeShellApplication {
    name = "thinkorswim-launcher";
    text = ''
      # The upstream installer and updater expect a writable ~/thinkorswim.
      # Use its default location; the installer overrides custom -dir values.
      tos_dir="$HOME/thinkorswim"
      export JAVA_HOME="${zulu21}"
      export INSTALL4J_JAVA_HOME_OVERRIDE="${zulu21}"

      # Serialize first-time installation without locking the running app.
      mkdir -p "''${XDG_CACHE_HOME:-$HOME/.cache}/thinkorswim"
      exec 9>"''${XDG_CACHE_HOME:-$HOME/.cache}/thinkorswim/install.lock"
      flock 9
      # install4j writes the executable before its runtime jars. Retain a
      # marker on failure so the next launch retries an interrupted install.
      if [ ! -x "$tos_dir/thinkorswim" ] || [ -e "$tos_dir/.nix-installing" ]; then
        mkdir -p "$tos_dir"
        touch "$tos_dir/.nix-installing"
        echo "Installing thinkorswim in $tos_dir..."
        sh ${installer} -q \
          '-Vcreate_icon$Boolean=false' \
          '-VexecuteLauncherAction$Boolean=false'
        test -x "$tos_dir/thinkorswim"
        test -s "$tos_dir/.install4j/i4jruntime.jar"
        rm "$tos_dir/.nix-installing"
      fi
      flock -u 9
      exec 9>&-

      if [ ! -x "$tos_dir/thinkorswim" ]; then
        echo "thinkorswim installation did not create $tos_dir/thinkorswim" >&2
        exit 1
      fi
      cd "$tos_dir"
      exec ./thinkorswim "$@"
    '';
  };
in
buildFHSEnv {
  pname = "thinkorswim";
  inherit version;

  # Supply native libraries for both Swing and JxBrowser's downloaded Chromium.
  # An FHS environment does not impose Flatpak's seccomp user-namespace denial;
  # keep Chromium's own sandbox enabled.
  targetPkgs =
    pkgs: with pkgs; [
      zulu21
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libGL
      libglvnd
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxkbcommon
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
      mesa
      nspr
      nss
      pango
      stdenv.cc.cc.lib
      systemd
      zlib
      bash
      coreutils
      gnugrep
      gnused
      gzip
      procps
      util-linux
      which
      xdg-utils
    ];
  multiArch = false;
  runScript = lib.getExe launcher;
  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/512x512/apps"
    cp ${desktopItem}/share/applications/thinkorswim.desktop "$out/share/applications/"
    cp ${icon} "$out/share/icons/hicolor/512x512/apps/thinkorswim.png"
  '';

  passthru = {
    inherit installer;
  };
  meta = {
    description = "Schwab thinkorswim desktop with a native Java and Chromium runtime";
    homepage = "https://www.schwab.com/trading/thinkorswim/desktop";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "thinkorswim";
  };
}
