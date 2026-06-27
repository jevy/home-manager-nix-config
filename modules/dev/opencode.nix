# OpenCode AI coding agent with OpenRouter provider
#
# Codex auth (ChatGPT OAuth → GPT-5.x) is provided by the
# `opencode-openai-codex-auth` plugin. The plugin is referenced by name in the
# `plugin` list and OpenCode auto-installs it from npm at first run. The full
# OpenAI provider/model block is required by the plugin (their docs reject
# minimal configs), so we vendor their upstream JSON at
# ./opencode-codex-auth/opencode-modern.json and merge its `provider.openai`
# into our settings.
#
# To update the vendored codex-auth config:
#   1. Find the latest tag:
#        gh api repos/numman-ali/opencode-openai-codex-auth/releases/latest --jq .tag_name
#   2. Download it over the existing file:
#        curl -fsSL https://raw.githubusercontent.com/numman-ali/opencode-openai-codex-auth/<TAG>/config/opencode-modern.json \
#          -o modules/dev/opencode-codex-auth/opencode-modern.json
#   3. Run `nix flake check` and rebuild.
{ inputs, ... }:
{
  flake.modules.homeManager.opencode =
    { config, pkgs, lib, ... }:
    let
      # Wrap opencode to inject OPENROUTER_API_KEY from sops at runtime
      wrappedOpencode = pkgs.symlinkJoin {
        name = "opencode-wrapped";
        paths = [ pkgs.opencode ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencode \
            --run 'export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouter_api_key.path} 2>/dev/null || true)'
        '';
      };

      codexAuthConfig = builtins.fromJSON (builtins.readFile ./opencode-codex-auth/opencode-modern.json);
    in
    {
      programs.opencode = {
        enable = true;
        package = wrappedOpencode;
        enableMcpIntegration = true;
        settings = {
          plugin = codexAuthConfig.plugin;
          provider = {
            openai = codexAuthConfig.provider.openai;
            openrouter = {
              models = {
                "minimax/minimax-m2.5" = { max_tokens = 32768; };
                "google/gemini-2.0-flash-exp" = { max_tokens = 32768; };
                "stepfun/step-3.5-flash:free" = { max_tokens = 32768; };
              };
            };
            local = {
              npm = "@ai-sdk/openai-compatible";
              name = "llama-swap (local)";
              options = {
                baseURL = "http://127.0.0.1:9292/v1";
              };
              models = {
                "qwen3-coder-30b" = {
                  name = "Qwen3-Coder-30B";
                  limit = {
                    context = 32768;
                    output = 32768;
                  };
                };
                "qwen3-1.7b-uncensored" = {
                  name = "Qwen3-1.7B-Uncensored";
                  limit = {
                    context = 32768;
                    output = 32768;
                  };
                };
              };
            };
          };
          model = "openrouter/minimax/minimax-m2.5";
        };
      };
    };
}
