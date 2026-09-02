# Claude Code pointed at OpenRouter instead of Anthropic, so the harness runs on
# GLM (or any other OpenRouter model) via OpenRouter's Anthropic-compatible
# Messages endpoint. No translating proxy is involved — OpenRouter serves
# `/api/v1/messages` in Anthropic wire format for non-Anthropic models too.
#
# Needs OPENROUTER_API_KEY in the environment at runtime.
{
  lib,
  writeShellApplication,
  claude-code,
}:

writeShellApplication {
  name = "glm-code";

  runtimeInputs = [ claude-code ];

  text = ''
    : "''${OPENROUTER_API_KEY:?glm-code: OPENROUTER_API_KEY is not set}"

    # Keep this session's credentials and state away from the real ~/.claude, so
    # an OpenRouter token never lands in the Anthropic-authenticated config.
    export CLAUDE_CONFIG_DIR="''${CLAUDE_CONFIG_DIR:-$HOME/.claude-glm}"
    mkdir -p "$CLAUDE_CONFIG_DIR"

    # Base URL is the API root, NOT .../api/v1 — Claude Code appends
    # `/v1/messages` itself, and the doubled path 404s while reporting the
    # misleading "model may not exist or you may not have access to it".
    export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
    export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
    unset ANTHROPIC_API_KEY # would otherwise take precedence over AUTH_TOKEN

    model="''${GLM_MODEL:-z-ai/glm-5.3-flash}"

    # Map every slot Claude Code can ask for onto the one model, so /model
    # switching and subagents cannot silently fall back to a real Claude id
    # that OpenRouter would then bill at Anthropic prices.
    export ANTHROPIC_MODEL="$model"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
    export ANTHROPIC_SMALL_FAST_MODEL="$model" # legacy name for the haiku slot
    export CLAUDE_CODE_SUBAGENT_MODEL="$model"

    # Claude Code assumes a 200k window for model ids it does not recognise, so
    # without this it would auto-compact at a fifth of what GLM actually offers.
    # 1048576 is the window every mainstream OpenRouter provider reports for this
    # model; the two that cap at 262144 (Reka, Io Net) are routed around on their
    # own, as OpenRouter only dispatches to providers that can fit the request.
    export CLAUDE_CODE_MAX_CONTEXT_TOKENS="''${CLAUDE_CODE_MAX_CONTEXT_TOKENS:-1048576}"

    # Background flourishes (session titles, conversation summaries) spend
    # tokens on a model whose id Claude Code does not recognise anyway.
    export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1
    export DISABLE_AUTOUPDATER=1

    exec claude "$@"
  '';

  meta = {
    description = "Claude Code running on GLM via OpenRouter's Anthropic-compatible endpoint";
    longDescription = ''
      Wraps claude-code with the environment needed to talk to OpenRouter's
      Anthropic-compatible Messages API, defaulting to z-ai/glm-5.3-flash.

      Set GLM_MODEL to run a different OpenRouter model, e.g.
      `GLM_MODEL=z-ai/glm-5.3 glm-code`. If that model's context window differs
      from GLM 5.3 Flash's 1M, override CLAUDE_CODE_MAX_CONTEXT_TOKENS to match,
      or Claude Code will auto-compact against the wrong number. State is kept in ~/.claude-glm rather
      than ~/.claude; override with CLAUDE_CONFIG_DIR.

      Note that Claude Code's own `/cost` reporting prices tokens against
      Anthropic's table and so is meaningless here — read OpenRouter's
      dashboard for real spend.
    '';
    homepage = "https://openrouter.ai/docs/api-reference/anthropic-compatible-api";
    license = lib.licenses.mit;
    mainProgram = "glm-code";
    inherit (claude-code.meta) platforms;
  };
}
