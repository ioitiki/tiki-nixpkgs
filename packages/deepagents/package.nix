{
  lib,
  python3Packages,
  fetchPypi,
  makeWrapper,
  ripgrep,
}:

let
  py = python3Packages;

  agentClientProtocol = py."agent-client-protocol";
  aiosqlite = py.aiosqlite;
  cloudpickle = py.cloudpickle;
  cryptography = py.cryptography;
  grpcio = py.grpcio;
  grpcioHealthChecking = py."grpcio-health-checking";
  grpcioTools = py."grpcio-tools";
  hatchling = py.hatchling;
  httpx = py.httpx;
  jsonschemaRs = py."jsonschema-rs";
  langchain = py.langchain;
  langchainAnthropic = py."langchain-anthropic";
  langchainCore = py."langchain-core";
  langchainGoogleGenai = py."langchain-google-genai";
  langchainOpenai = py."langchain-openai";
  langgraphApi = py.buildPythonPackage rec {
    pname = "langgraph-api";
    version = "0.7.86";
    pyproject = true;

    src = fetchPypi {
      inherit version;
      pname = "langgraph_api";
      hash = "sha256-NrjWZc0bujBSoBxUOJUKz8BdH57jL3xRoPA/IWDS+g8=";
    };

    build-system = [ hatchling ];

    pythonRelaxDeps = true;
    pythonRemoveDeps = [ "langsmith" ];

    dependencies = [
      sseStarlette
      starlette
      watchfiles
      langgraph
      langgraphCheckpoint
      orjson
      uvicorn
      langsmith
      httpx
      langchainCore
      tenacity
      jsonschemaRs
      structlog
      pyjwt
      cryptography
      langgraphSdk
      cloudpickle
      langgraphRuntimeInmem
      truststore
      protobuf
      grpcio
      grpcioTools
      grpcioHealthChecking
      opentelemetryApi
      opentelemetrySdk
      opentelemetryExporterOtlpProtoHttp
      uuidUtils
    ];

    doCheck = false;

    pythonImportsCheck = [ "langgraph_api" ];
  };
  langgraphCheckpoint = py."langgraph-checkpoint";
  langgraph = py.langgraph;
  langgraphCheckpointSqlite = py."langgraph-checkpoint-sqlite";
  langgraphCli = py."langgraph-cli";
  langgraphRuntimeInmem = py."langgraph-runtime-inmem";
  langgraphSdk = py."langgraph-sdk";
  langsmith = py.langsmith;
  markdownify = py.markdownify;
  mcp = py.mcp;
  opentelemetryApi = py."opentelemetry-api";
  opentelemetryExporterOtlpProtoHttp = py."opentelemetry-exporter-otlp-proto-http";
  opentelemetrySdk = py."opentelemetry-sdk";
  orjson = py.orjson;
  pdmBackend = py."pdm-backend";
  pillow = py.pillow;
  promptToolkit = py."prompt-toolkit";
  protobuf = py.protobuf;
  pyjwt = py.pyjwt;
  pyperclip = py.pyperclip;
  pythonDotenv = py."python-dotenv";
  pyyaml = py.pyyaml;
  requests = py.requests;
  rich = py.rich;
  sseStarlette = py."sse-starlette";
  starlette = py.starlette;
  structlog = py.structlog;
  setuptools = py.setuptools;
  tenacity = py.tenacity;
  textual = py.textual;
  textualAutocomplete = py."textual-autocomplete";
  textualSpeedups = py."textual-speedups";
  tiktoken = py.tiktoken;
  tomliW = py."tomli-w";
  truststore = py.truststore;
  typingExtensions = py."typing-extensions";
  uuidUtils = py."uuid-utils";
  uvicorn = py.uvicorn;
  watchfiles = py.watchfiles;
  wcmatch = py.wcmatch;
  wheel = py.wheel;

  deepagents = py.buildPythonPackage rec {
    pname = "deepagents";
    version = "0.4.11";
    pyproject = true;

    src = fetchPypi {
      inherit version;
      pname = "deepagents";
      hash = "sha256-atqb07E2uuKUqhUgV1v4XoBsBRSAfW479Dx7PQi0QwY=";
    };

    build-system = [
      setuptools
      wheel
    ];

    pythonRelaxDeps = true;

    dependencies = [
      langchainCore
      langchain
      langchainAnthropic
      langchainGoogleGenai
      wcmatch
    ];

    doCheck = false;

    pythonImportsCheck = [ "deepagents" ];
  };

  deepagentsAcp = py.buildPythonPackage rec {
    pname = "deepagents-acp";
    version = "0.0.4";
    pyproject = true;

    src = fetchPypi {
      inherit version;
      pname = "deepagents_acp";
      hash = "sha256-23JQr2ole+GZYP2I3b+kZnUAdB76wW9dqKs+M/jO2mM=";
    };

    build-system = [ hatchling ];

    pythonRelaxDeps = true;

    dependencies = [
      agentClientProtocol
      deepagents
      pythonDotenv
    ];

    doCheck = false;

    pythonImportsCheck = [ "deepagents_acp" ];
  };

  tavilyPython = py.buildPythonPackage rec {
    pname = "tavily-python";
    version = "0.7.23";
    format = "setuptools";

    src = fetchPypi {
      inherit version;
      pname = "tavily_python";
      hash = "sha256-O5IjLg4pq2iJi3ZfKBu08sZQsCIQtkr/vEjhUpLpYWE=";
    };

    propagatedBuildInputs = [
      requests
      tiktoken
      httpx
    ];

    doCheck = false;

    pythonImportsCheck = [ "tavily" ];
  };

  langchainMcpAdapters = py.buildPythonPackage rec {
    pname = "langchain-mcp-adapters";
    version = "0.2.2";
    pyproject = true;

    src = fetchPypi {
      inherit version;
      pname = "langchain_mcp_adapters";
      hash = "sha256-EtOeka5DicVLYbIhCU5ThQtuFSk02LwQyAZl1gDnZTA=";
    };

    build-system = [ pdmBackend ];

    pythonRelaxDeps = true;

    dependencies = [
      langchainCore
      mcp
      typingExtensions
    ];

    doCheck = false;

    pythonImportsCheck = [ "langchain_mcp_adapters" ];
  };

  langgraphServerDeps = [
    langgraphApi
    langgraphCli
    langgraph
    langgraphCheckpoint
    langgraphCheckpointSqlite
    langgraphRuntimeInmem
    langgraphSdk
    pythonDotenv
    sseStarlette
    starlette
    watchfiles
    orjson
    uvicorn
    langsmith
    httpx
    langchainCore
    tenacity
    jsonschemaRs
    structlog
    pyjwt
    cryptography
    cloudpickle
    truststore
    protobuf
    grpcio
    grpcioTools
    grpcioHealthChecking
    opentelemetryApi
    opentelemetrySdk
    opentelemetryExporterOtlpProtoHttp
    uuidUtils
  ];

  langgraphServerPythonPath = lib.makeSearchPath py.python.sitePackages (
    map (lib.getOutput "out") langgraphServerDeps
  );

  deepagentsCliDeps = [
    deepagents
    langchain
    langgraph
    langgraphCheckpointSqlite
    langgraphCli
    langgraphApi
    langgraphRuntimeInmem
    langgraphSdk
    httpx
    langchainAnthropic
    langchainGoogleGenai
    langchainOpenai
    textual
    textualAutocomplete
    textualSpeedups
    promptToolkit
    rich
    markdownify
    langsmith
    tavilyPython
    pyperclip
    uuidUtils
    pythonDotenv
    requests
    pillow
    pyyaml
    aiosqlite
    tomliW
    langchainMcpAdapters
    deepagentsAcp
  ];
in
py.buildPythonApplication rec {
  pname = "deepagents-cli";
  version = "0.0.34";
  pyproject = true;

  src = fetchPypi {
    inherit version;
    pname = "deepagents_cli";
    hash = "sha256-tPouNjP9nyXKRoIYR/X+YhyoXOv8Vo0xsgobLo0EuRM=";
  };

  build-system = [ hatchling ];

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace deepagents_cli/server.py \
      --replace-fail "import signal" $'import signal\nimport shutil' \
      --replace-fail $'        sys.executable,\n        "-m",\n        "langgraph_cli",' '        shutil.which("langgraph") or "langgraph",'
  '';

  pythonRelaxDeps = true;

  # Keep the default package focused on the core CLI. The published sdist pulls
  # in remote sandbox backends that are not packaged in this repo yet.
  pythonRemoveDeps = [
    "daytona"
    "modal"
    "runloop-api-client"
    "langsmith"
  ];

  dependencies = deepagentsCliDeps;

  doCheck = false;

  pythonImportsCheck = [ "deepagents_cli" ];

  postFixup = ''
    makeWrapper ${py.python.interpreter} $out/bin/langgraph \
      --set PYTHONNOUSERSITE true \
      --prefix PYTHONPATH : "$out/${py.python.sitePackages}:${langgraphServerPythonPath}:${py.makePythonPath deepagentsCliDeps}" \
      --add-flags "-m langgraph_cli"

    wrapProgram $out/bin/deepagents \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
    wrapProgram $out/bin/deepagents-cli \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  meta = {
    description = "Terminal interface for Deep Agents";
    homepage = "https://github.com/langchain-ai/deepagents";
    license = lib.licenses.mit;
    mainProgram = "deepagents";
    platforms = lib.platforms.unix;
  };
}
