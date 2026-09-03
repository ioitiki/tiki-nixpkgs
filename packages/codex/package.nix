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
  # Codex enables rusty_v8's pointer-compression sandbox, whose archive and
  # generated Rust binding are published together by Codex upstream. Fetch the
  # exact pair up front so the derivation stays sandbox-safe.
  rustyV8Version = "150.4.0";
  rustyV8ArtifactsByPlatform = {
    "x86_64-linux" = {
      target = "x86_64-unknown-linux-gnu";
      archiveHash = "sha256-o1x10fJuapg4haRbM0kKTr5U8FBQVosyuJz7QhswtYM=";
      bindingHash = "sha256-dyeCauR5vbZF6Acjn7EtH44uI956bPFvXuWSaQ0dhQY=";
    };
    "aarch64-linux" = {
      target = "aarch64-unknown-linux-gnu";
      archiveHash = "sha256-0VF+7UBUaFNwKbAF1f6ZfsdNXI01H5FrOm3yC30oEbo=";
      bindingHash = "sha256-dyeCauR5vbZF6Acjn7EtH44uI956bPFvXuWSaQ0dhQY=";
    };
  };
  rustyV8Artifacts =
    rustyV8ArtifactsByPlatform.${stdenv.hostPlatform.system}
      or (throw "codex: unsupported platform ${stdenv.hostPlatform.system}");
  rustyV8ReleaseBase = "https://github.com/openai/codex/releases/download/rusty-v8-v${rustyV8Version}";
  rustyV8Archive = fetchurl {
    url = "${rustyV8ReleaseBase}/librusty_v8_ptrcomp_sandbox_release_${rustyV8Artifacts.target}.a.gz";
    hash = rustyV8Artifacts.archiveHash;
  };
  rustyV8Binding = fetchurl {
    url = "${rustyV8ReleaseBase}/src_binding_ptrcomp_sandbox_release_${rustyV8Artifacts.target}.rs";
    hash = rustyV8Artifacts.bindingHash;
  };
  rawCodex = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "codex";
    version = "0.153.0";

    src = fetchFromGitHub {
      owner = "openai";
      repo = "codex";
      tag = "rust-v${finalAttrs.version}";
      hash = "sha256-dSuFpqsMH248F+fdvN0wxMyhqFRHN92FLF7ufUpe0WE=";
    };

    sourceRoot = "${finalAttrs.src.name}/codex-rs";

    cargoHash = "sha256-GG6kOXmCdq+bZLU2ul0DIVL8lDuweayvZvXn6+bcUZw=";

    # Match the primary Linux binaries in Codex's upstream release bundle.
    # An unrestricted workspace build also compiles internal samples that are
    # not release artifacts and may not compile under the release profile.
    cargoBuildFlags = [
      "--bin"
      "codex"
      "--bin"
      "codex-code-mode-host"
      "--bin"
      "codex-responses-api-proxy"
      "--bin"
      "bwrap"
    ];

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
      RUSTY_V8_SRC_BINDING_PATH = rustyV8Binding;
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
