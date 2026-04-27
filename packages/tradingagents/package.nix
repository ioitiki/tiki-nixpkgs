{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
}:

let
  py = python3Packages;

  backtrader = py.buildPythonPackage rec {
    pname = "backtrader";
    version = "1.9.78.123";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      hash = "sha256-mgelFrDekVVTmjXFbpQE2HEd1wILPTezBJXoPhudXf0=";
    };

    doCheck = false;

    pythonImportsCheck = [ "backtrader" ];
  };

  stockstats = py.buildPythonPackage rec {
    pname = "stockstats";
    version = "0.6.5";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-K8gb/xh6uataTBfOwLvsRqWxCNIYeNL7yJIes6/EhgY=";
    };

    build-system = [ py.setuptools ];

    dependencies = [ py.pandas ];

    doCheck = false;

    pythonImportsCheck = [ "stockstats" ];
  };
in
py.buildPythonApplication rec {
  pname = "tradingagents";
  version = "0.2.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "TauricResearch";
    repo = "TradingAgents";
    tag = "v${version}";
    hash = "sha256-xQYEAz+NazdIkEzGP2wpiUvUN2ZHsnsoJaDn9HdJgvw=";
  };

  build-system = [ py.setuptools ];

  pythonRelaxDeps = true;

  dependencies = [
    backtrader
    py."langchain-anthropic"
    py."langchain-core"
    py."langchain-experimental"
    py."langchain-google-genai"
    py."langchain-openai"
    py.langgraph
    py.pandas
    py.parsel
    py.pydantic
    py."python-dateutil"
    py."python-dotenv"
    py.pytz
    py.questionary
    py."rank-bm25"
    py.redis
    py.requests
    py.rich
    stockstats
    py.tqdm
    py.typer
    py."typing-extensions"
    py.yfinance
  ];

  doCheck = false;

  pythonImportsCheck = [ "tradingagents" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/tradingagents --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Multi-agent LLM financial trading framework";
    homepage = "https://github.com/TauricResearch/TradingAgents";
    changelog = "https://github.com/TauricResearch/TradingAgents/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "tradingagents";
    platforms = lib.platforms.unix;
  };
}
