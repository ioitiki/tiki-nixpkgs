{ pkgs }:

let
  # Download the installer
  twsInstaller = pkgs.fetchurl {
    url = "https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh";
    sha256 = "sha256-J8zG7kIFTWCihAZkw3iuw49mxMXzcfUn9fa2nvGP4UM=";
  };

  # Create an FHS environment for TWS
  twsFHS = pkgs.buildFHSEnv {
    name = "ib-tws";

    targetPkgs =
      pkgs: with pkgs; [
        # Java runtime requirements
        jdk17
        zlib
        freetype
        fontconfig
        libx11
        libxext
        libxrender
        libxtst
        libxi
        libxrandr
        alsa-lib
        # GTK and desktop integration
        gtk3
        glib
        pango
        cairo
        gdk-pixbuf
        atk
        # Additional libraries that might be needed
        libGL
        libglvnd
        nspr
        nss
        libdrm
        mesa
        expat
        libxkbcommon
        # System utilities
        coreutils
        bash
        which
        procps
      ];

    multiPkgs =
      pkgs: with pkgs; [
        # 32-bit libraries if needed
        zlib
        freetype
        fontconfig
      ];

    runScript = pkgs.writeScript "tws-launcher" ''
      #!${pkgs.bash}/bin/bash
      set -e

      TWS_HOME="$HOME/.local/share/ib-tws"
      TWS_INSTALLER="${twsInstaller}"

      # Check if TWS is installed
      if [ ! -d "$TWS_HOME" ]; then
        echo "TWS not found at $TWS_HOME"
        echo "First time setup - running installer..."
        echo ""
        echo "Please follow the installer prompts."
        echo "Default installation directory: $TWS_HOME"
        echo ""
        mkdir -p "$TWS_HOME"

        # Copy installer to temp location
        TEMP_INSTALLER="/tmp/tws-installer-$$.sh"
        cp "$TWS_INSTALLER" "$TEMP_INSTALLER"
        chmod +x "$TEMP_INSTALLER"

        # Run installer
        "$TEMP_INSTALLER"
        rm -f "$TEMP_INSTALLER"

        echo ""
        echo "Installation complete. You can now run 'ib-tws' to start TWS."
        exit 0
      fi

      # Find and run TWS - search for the actual executable location
      if [ -x "$TWS_HOME/tws" ]; then
        cd "$TWS_HOME"
        exec "$TWS_HOME/tws" "$@"
      else
        # Search for TWS in versioned directories
        TWS_EXEC=$(find "$TWS_HOME" -type f -name "tws" -executable 2>/dev/null | head -n 1)
        if [ -n "$TWS_EXEC" ]; then
          cd "$(dirname "$TWS_EXEC")"
          exec "$TWS_EXEC" "$@"
        else
          echo "TWS executable not found in $TWS_HOME"
          echo "You may need to reinstall. Delete $TWS_HOME and run this command again."
          exit 1
        fi
      fi
    '';

    profile = ''
      export JAVA_HOME="${pkgs.jdk17}"
      export PATH="$JAVA_HOME/bin:$PATH"
    '';
  };
in
twsFHS
