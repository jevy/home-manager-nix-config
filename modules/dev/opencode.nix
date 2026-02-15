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
                "anthropic/claude-sonnet-4-20250514" = { };
              };
            };
          };
          model = "openrouter/anthropic/claude-sonnet-4-20250514";
        };
      };
    };
}
