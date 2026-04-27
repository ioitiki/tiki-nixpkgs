{
  lib,
  fetchPypi,
  makeWrapper,
  python313Packages,
  ripgrep,
  writableTmpDirAsHomeHook,
}:

let
  py = python313Packages;

  kosong = py.buildPythonPackage rec {
    pname = "kosong";
    version = "0.51.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-MlOQjHKYtGtWjA/Op4qydyfw/5Ok1vkOnKqW4mFtY4o=";
    };

    build-system = [ py.uv-build ];

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build>=0.8.5,<0.10.0" "uv_build>=0.8.5"
    '';

    pythonRelaxDeps = true;

    dependencies = [
      py.anthropic
      py.google-genai
      py.jsonschema
      py.loguru
      py.mcp
      py.openai
      py.pydantic
      py.python-dotenv
      py.typing-extensions
    ];

    doCheck = false;

    pythonImportsCheck = [ "kosong" ];
  };

  pykaos = py.buildPythonPackage rec {
    pname = "pykaos";
    version = "0.9.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-moGi4FSOxvgFH+PRAh/bcDYMYG3AjfrPT+5l6K450DU=";
    };

    build-system = [ py.uv-build ];

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build>=0.8.5,<0.9.0" "uv_build>=0.8.5"
    '';

    pythonRelaxDeps = true;

    dependencies = [
      py.aiofiles
      py.asyncssh
    ];

    doCheck = false;

    pythonImportsCheck = [ "kaos" ];
  };

  ripgrepy = py.buildPythonPackage rec {
    pname = "ripgrepy";
    version = "2.2.0";
    format = "setuptools";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-TEPGE4TyV2YAB6zScaXY5KvpvgsGnEGNCR9ymeCAyp0=";
    };

    doCheck = false;

    pythonImportsCheck = [ "ripgrepy" ];
  };

  streamingjson = py.buildPythonPackage rec {
    pname = "streamingjson";
    version = "0.0.5";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-x7rs4P9+vOCiprqgwTlN/f4kpKYvljXUoXwrVI/163Y=";
    };

    doCheck = false;

    pythonImportsCheck = [ "streamingjson" ];
  };

  scalarFastapi = py."scalar-fastapi".overridePythonAttrs (_old: {
    doCheck = false;
  });

  runtimePath = lib.makeBinPath [ ripgrep ];
in
py.buildPythonApplication rec {
  pname = "kimi-cli";
  version = "1.38.0";
  pyproject = true;

  src = fetchPypi {
    inherit version;
    pname = "kimi_cli";
    hash = "sha256-68LW3B1vFBhLtOkPNaUoTjh1m+zrJ/Lrc8ulAd/xb+4=";
  };

  nativeBuildInputs = [ makeWrapper ];
  build-system = [ py.uv-build ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "uv_build>=0.8.5,<0.10.0" "uv_build>=0.8.5"
  '';

  pythonRelaxDeps = true;

  dependencies = [
    py."agent-client-protocol"
    py.aiofiles
    py.aiohttp
    py.fastapi
    py.fastmcp
    py.httpx
    py.jinja2
    py.keyring
    py.loguru
    py.lxml
    py.pillow
    py.prompt-toolkit
    py.pydantic
    py.pyyaml
    py.rich
    py.setproctitle
    py.tenacity
    py.tomlkit
    py.trafilatura
    py.typer
    py.uvicorn
    py.websockets
    kosong
    pykaos
    ripgrepy
    scalarFastapi
    streamingjson
  ]
  ++ py.httpx.optional-dependencies.socks
  ++ py.uvicorn.optional-dependencies.standard;

  doCheck = false;

  pythonImportsCheck = [ "kimi_cli" ];

  postFixup = ''
    wrapProgram $out/bin/kimi \
      --set KIMI_CLI_NO_AUTO_UPDATE 1 \
      --prefix PATH : ${runtimePath}
    wrapProgram $out/bin/kimi-cli \
      --set KIMI_CLI_NO_AUTO_UPDATE 1 \
      --prefix PATH : ${runtimePath}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/kimi --help >/dev/null
    $out/bin/kimi --version >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Kimi Code CLI terminal agent";
    homepage = "https://github.com/MoonshotAI/kimi-cli";
    changelog = "https://github.com/MoonshotAI/kimi-cli/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "kimi";
    platforms = lib.platforms.unix;
  };
}
