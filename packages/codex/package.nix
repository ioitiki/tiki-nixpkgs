{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  installShellFiles,
  clang,
  cmake,
  gitMinimal,
  libcap,
  libclang,
  makeBinaryWrapper,
  nix-update-script,
  pkg-config,
  runCommand,
  openssl,
  ripgrep,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:
let
  # `rusty_v8` tries to download this archive during the build by default.
  # Fetch it up front so the derivation stays sandbox-safe.
  rustyV8ByPlatform = {
    "x86_64-linux" = {
      url = "https://github.com/denoland/rusty_v8/releases/download/v146.4.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
      hash = "sha256-5ktNmeSuKTouhGJEqJuAF4uhA4LBP7WRwfppaPUpEVM=";
    };
    "aarch64-linux" = {
      url = "https://github.com/denoland/rusty_v8/releases/download/v146.4.0/librusty_v8_release_aarch64-unknown-linux-gnu.a.gz";
      hash = "sha256-2/FlsHyBvbBUvARrQ9I+afz3vMGkwbW0d2mDpxBi7Ng=";
    };
  };
  rustyV8Archive = fetchurl (
    rustyV8ByPlatform.${stdenv.hostPlatform.system}
      or (throw "codex: unsupported platform ${stdenv.hostPlatform.system}")
  );
  rawCodex = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "codex";
    version = "0.142.0";

    src = fetchFromGitHub {
      owner = "openai";
      repo = "codex";
      tag = "rust-v${finalAttrs.version}";
      hash = "sha256-F8wlv0vSuljNFDgIzoeuVxvD0dk90z2FBtpBTMih7AA=";
    };

    sourceRoot = "${finalAttrs.src.name}/codex-rs";

    cargoHash = "sha256-fvEFNE12J6zaLZrN6oQB8X+jXoKPSCWrL17Sl28+7/c=";
    depsExtraArgs = {
      # crates.io rejects python-requests' default User-Agent on the legacy
      # /api/v1/crates/.../download endpoint used by fetch-cargo-vendor.
      preBuild = ''
        orig_fetch_cargo_vendor_util="$(command -v fetch-cargo-vendor-util)"
        mkdir -p .nix-cargo-vendor-bin
        sed '/session = requests.Session()/a\    session.headers.update({"User-Agent": "tiki-nixpkgs codex package update (https://github.com/ioitiki/tiki-nixpkgs)"})' \
          "$orig_fetch_cargo_vendor_util" \
          > .nix-cargo-vendor-bin/fetch-cargo-vendor-util
        chmod +x .nix-cargo-vendor-bin/fetch-cargo-vendor-util
        export PATH="$PWD/.nix-cargo-vendor-bin:$PATH"
      '';
    };

    nativeBuildInputs = [
      clang
      cmake
      gitMinimal
      installShellFiles
      makeBinaryWrapper
      pkg-config
    ];

    buildInputs = [
      libcap
      libclang
      openssl
    ];

    # NOTE: set LIBCLANG_PATH so bindgen can locate libclang, and adjust
    # warning-as-error flags to avoid known false positives (GCC's
    # stringop-overflow in BoringSSL's a_bitstr.cc) while keeping Clang's
    # character-conversion warning-as-error disabled.
    env = {
      LIBCLANG_PATH = "${lib.getLib libclang}/lib";
      RUSTY_V8_ARCHIVE = rustyV8Archive;
      NIX_CFLAGS_COMPILE = toString (
        lib.optionals stdenv.cc.isGNU [
          "-Wno-error=stringop-overflow"
        ]
        ++ lib.optionals stdenv.cc.isClang [
          "-Wno-error=character-conversion"
        ]
      );
    };

    # NOTE: part of the test suite requires access to networking, local shells,
    # apple system configuration, etc. since this is a very fast moving target
    # (for now), with releases happening every other day, constantly figuring out
    # which tests need to be skipped, or finding workarounds, was too burdensome,
    # and in practice not adding any real value. this decision may be reversed in
    # the future once this software stabilizes.
    doCheck = false;

    postInstall = lib.optionalString installShellCompletions ''
      installShellCompletion --cmd codex \
        --bash <($out/bin/codex completion bash) \
        --fish <($out/bin/codex completion fish) \
        --zsh <($out/bin/codex completion zsh)
    '';

    postFixup = ''
      wrapProgram $out/bin/codex --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [ versionCheckHook ];

    passthru = {
      updateScript = nix-update-script {
        extraArgs = [
          "--version-regex"
          "^rust-v(\\d+\\.\\d+\\.\\d+)$"
        ];
      };
    };

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      maintainers = with lib.maintainers; [
        malo
        delafthi
      ];
      platforms = lib.platforms.unix;
    };
  });
in
runCommand "codex-${rawCodex.version}"
  {
    pname = "codex";
    inherit (rawCodex) version meta;
    passthru = rawCodex.passthru // {
      unwrapped = rawCodex;
    };
  }
  ''
    mkdir -p "$out/bin" "$out/libexec/codex"

    if [ -d "${rawCodex}/share" ]; then
      cp -a "${rawCodex}/share" "$out/share"
    fi

    for binary in "${rawCodex}"/bin/*; do
      name="$(basename "$binary")"
      case "$name" in
        codex|.codex-wrapped)
          ;;
        *)
          ln -s "$binary" "$out/libexec/codex/$name"
          ;;
      esac
    done

    cat > "$out/bin/codex" <<EOF
    #!${stdenv.shell}
    export PATH="${lib.makeBinPath [ ripgrep ]}:\$PATH:$out/libexec/codex"
    exec "${rawCodex}/bin/.codex-wrapped" "\$@"
    EOF
    chmod +x "$out/bin/codex"
  ''
