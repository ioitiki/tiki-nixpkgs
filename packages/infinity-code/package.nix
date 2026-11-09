{
  lib,
  stdenv,
  rustPlatform,
  buildNpmPackage,
  fetchFromGitHub,
  cmake,
  makeWrapper,
  bubblewrap,
  gitMinimal,
  jujutsu,
  ripgrep,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  version = "0.2.0";
  rev = "1abc6fcff1f186124f924b56aa92c3a3684c90c5";

  src = fetchFromGitHub {
    owner = "hydro-project";
    repo = "infinity";
    inherit rev;
    hash = "sha256-XnOhHgcDREfrkR8oJfmKHEA8t0TIzIlR9b0vCkFHSKc=";
  };

  uiNodeModules = buildNpmPackage {
    pname = "infinity-ui-node-modules";
    inherit version src;

    sourceRoot = "${src.name}/infinity-ui";

    npmDepsHash = "sha256-XPcMBNDs2ScvDipvY08Zjl2owPqYh8NffX4jzn1cU6Q=";

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall
      cp -r node_modules "$out"
      runHook postInstall
    '';
  };

  web = buildNpmPackage {
    pname = "infinity-web";
    inherit version src;

    sourceRoot = "${src.name}/infinity-web";

    npmDepsHash = "sha256-ihtZPEeMXPmjNzTPqdsN4TsTnUkMt2h3+n+z8tnArio=";

    preBuild = ''
      chmod -R u+w ../infinity-ui
      cp -r ${uiNodeModules} ../infinity-ui/node_modules
      chmod -R u+w ../infinity-ui/node_modules
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/* "$out/"
      runHook postInstall
    '';
  };

  runtimeTools = [
    gitMinimal
    jujutsu
    ripgrep
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    bubblewrap
  ];
in
rustPlatform.buildRustPackage {
  pname = "infinity-code";
  inherit version src;

  __structuredAttrs = true;

  cargoHash = "sha256-ZmkdUFl8/WQ97ChrBHA7cbTR+yb4Jxp/wbttzx8ZKKY=";

  nativeBuildInputs = [
    cmake
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    bubblewrap
  ];

  cargoBuildFlags = [
    "--package"
    "infinity-agent-cli"
    "--features"
    "infinity-agent-cli/bundled-web"
    "--package"
    "infinity-daemon"
    "--package"
    "infinity-provider-bedrock"
    "--package"
    "sandbox-local"
    "--package"
    "rap-steering-server"
    "--package"
    "rap-github-event-poller"
  ];

  postPatch = ''
    # Use the prebuilt web assets from buildNpmPackage instead of running npm ci in build.rs.
    cat > crates/infinity-daemon/build.rs <<'EOF'
    fn main() {}
    EOF

    # Skip running `cargo install` when registering crates already bundled in this package.
    substituteInPlace crates/infinity-agent-cli/src/install.rs \
      --replace-fail '    let mut cmd = Command::new("cargo");' '    if git.is_none()
        && path.is_none()
        && features.is_empty()
        && std::env::current_exe()
            .ok()
            .and_then(|e| e.parent().map(|d| d.join(crate_name)))
            .is_some_and(|p| p.is_file())
    {
        return Ok(());
    }
    let mut cmd = Command::new("cargo");'
  '';

  preBuild = ''
    mkdir -p infinity-web/dist
    cp -r ${web}/* infinity-web/dist/
  '';

  # Upstream integration tests spawn git/jj/bwrap sandboxes and network sockets.
  doCheck = false;

  postFixup = ''
    for bin in infinity infinity-daemon sandbox-local; do
      wrapProgram "$out/bin/$bin" \
        --prefix PATH : "$out/bin:${lib.makeBinPath runtimeTools}" \
        --run '
          if [ -n "''${HOME-}" ]; then
            mkdir -p "$HOME/.infinity"
            if [ ! -e "$HOME/.infinity/providers.json" ]; then
              cat > "$HOME/.infinity/providers.json" <<JSON
{
  "bedrock": {
    "command": [
      "infinity-provider-bedrock"
    ],
    "crate_name": "infinity-provider-bedrock"
  }
}
JSON
            fi
            if [ ! -e "$HOME/.infinity/rap.json" ]; then
              cat > "$HOME/.infinity/rap.json" <<JSON
{
  "tool_sets": [
    {
      "type": "toolset_command",
      "command": "sandbox-local",
      "id": "sandbox-local",
      "crate_name": "sandbox-local"
    }
  ]
}
JSON
            fi
          fi
        '
    done
    ln -s infinity "$out/bin/infinity-code"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckProgram = "${placeholder "out"}/bin/infinity";
  versionCheckProgramArg = "--version";

  passthru = {
    inherit uiNodeModules web;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Infinity Code AI coding agent CLI, daemon, Bedrock provider, and RAP servers";
    homepage = "https://infinity.hydro.run/docs/infinity-code/overview/";
    license = lib.licenses.asl20;
    mainProgram = "infinity";
    platforms = lib.platforms.unix;
  };
}
