# OpenCode AI coding agent with OpenRouter provider
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
    in
    {
      programs.opencode = {
        enable = true;
        package = wrappedOpencode;
        enableMcpIntegration = true;
        settings = {
          provider = {
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
                "qwen3.5-35b" = {
                  name = "Qwen3.5-35B";
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
