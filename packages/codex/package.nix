{
  lib,
  stdenv,
  callPackage,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  bubblewrap,
  clang,
  cmake,
  gitMinimal,
  libcap,
  libclang,
  librusty_v8 ? callPackage ./librusty_v8.nix {
    inherit (callPackage ./fetchers.nix { }) fetchLibrustyV8;
  },
  librusty_v8_src_binding ? callPackage ./librusty_v8_src_binding.nix {
    inherit (callPackage ./fetchers.nix { }) fetchLibrustyV8SrcBinding;
  },
  lld,
  makeBinaryWrapper,
  nix-update-script,
  pkg-config,
  openssl,
  ripgrep,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
  _experimental-update-script-combinators,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "codex";
  version = "0.162.0";

  src = fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    tag = "rust-v${finalAttrs.version}";
    hash = "sha256-YG/9hFOCl4cMYzjaH/3gBid4osxcrvCYQUDDzdbIygo=";
  };

  sourceRoot = "${finalAttrs.src.name}/codex-rs";

  cargoHash = "sha256-UTu+ws1DqL375C+1jaVI9HBqDHnTuAQr7/h1rSzsEzg=";

  depsExtraArgs = {
    # crates.io rejects python-requests' default User-Agent on the legacy
    # /api/v1/crates/.../download endpoint used by fetch-cargo-vendor, and
    # rate-limits it with 429s that the stock script does not retry.
    # Download from the static CDN instead (no rate limit, same tarballs)
    # and retry 429s as defense-in-depth.
    preBuild = ''
      orig_fetch_cargo_vendor_util="$(command -v fetch-cargo-vendor-util)"
      mkdir -p .nix-cargo-vendor-bin
      sed \
        -e '/session = requests.Session()/a\    session.headers.update({"User-Agent": "tiki-nixpkgs codex package update (https://github.com/ioitiki/tiki-nixpkgs)"})' \
        -e 's|https://crates.io/api/v1/crates/{pkg\["name"\]}/{pkg\["version"\]}/download|https://static.crates.io/crates/{pkg["name"]}/{pkg["name"]}-{pkg["version"]}.crate|' \
        -e 's/total=5,/total=10,/' \
        -e 's/backoff_factor=0.5,/backoff_factor=2,/' \
        -e 's/status_forcelist=\[500, 502, 503, 504\]/status_forcelist=[429, 500, 502, 503, 504]/' \
        "$orig_fetch_cargo_vendor_util" \
        > .nix-cargo-vendor-bin/fetch-cargo-vendor-util
      chmod +x .nix-cargo-vendor-bin/fetch-cargo-vendor-util
      export PATH="$PWD/.nix-cargo-vendor-bin:$PATH"
    '';
  };

  __structuredAttrs = true;

  # Match upstream's release build for the codex binary, plus its
  # codex-code-mode-host runtime companion for out-of-process V8 execution.
  cargoBuildFlags = [
    "--package"
    "codex-cli"
    "--package"
    "codex-code-mode-host"
  ];
  cargoCheckFlags = [
    "--package"
    "codex-cli"
    "--package"
    "codex-code-mode-host"
  ];

  patches = [
    # https://github.com/openai/codex/issues/48195
    ./no-daemon_auto_start.patch
  ];

  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "thin"' "" \
      --replace-fail 'codegen-units = 4' ""

    sed -i '1i#![recursion_limit = "256"]' chatgpt/src/lib.rs
  '';

  nativeBuildInputs = [
    clang
    cmake
    gitMinimal
    installShellFiles
    makeBinaryWrapper
    pkg-config
  ];

  buildInputs = [
    libclang
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    libcap
  ];

  # NOTE: set LIBCLANG_PATH so bindgen can locate libclang, and adjust
  # warning-as-error flags to avoid known false positives (GCC's
  # stringop-overflow in BoringSSL's a_bitstr.cc) while keeping Clang's
  # character-conversion warning-as-error disabled.
  env = {
    LIBCLANG_PATH = "${lib.getLib libclang}/lib";
    NIX_CFLAGS_COMPILE = toString (
      lib.optionals stdenv.cc.isGNU [
        "-Wno-error=stringop-overflow"
      ]
      ++ lib.optionals stdenv.cc.isClang [
        "-Wno-error=character-conversion"
      ]
    );
    RUSTY_V8_ARCHIVE = librusty_v8;
    RUSTY_V8_SRC_BINDING_PATH = librusty_v8_src_binding;
  }
  // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    # Link with lld on Darwin. nixpkgs' classic open-source ld64 fails to insert
    # ARM64 branch thunks for this binary, producing `b(l) ARM64 branch out of range`.
    NIX_CFLAGS_LINK = "-fuse-ld=${lib.getExe' lld "ld64.lld"}";
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
    wrapProgram $out/bin/codex --prefix PATH : ${
      lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ])
    }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.updateScript = _experimental-update-script-combinators.sequence [
    (nix-update-script {
      extraArgs = [
        "--use-github-releases"
        "--version-regex"
        "^rust-v(\\d+\\.\\d+\\.\\d+)$"
      ];
    })
    ./update-librusty.sh
  ];

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    maintainers = with lib.maintainers; [
      delafthi
      jeafleohj
      malo
    ];
    platforms = lib.platforms.unix;
  };
})
