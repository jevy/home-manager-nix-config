# MCP (Model Context Protocol) server configuration
# Wraps mcp/config.nix and provides home-manager module for MCP configs
{ inputs, ... }:
{
  flake.modules.homeManager.mcp =
    { config, pkgs, ... }:
    let
      mcpConfigVSCode = import ../../mcp/config.nix {
        nixpkgsInput = inputs.nixpkgs;
        mcpServersNixInput = inputs.mcp-servers-nix;
        system = pkgs.system;
        flavor = "vscode";
        fileName = "mcp_settings.json";
      };
      mcpConfigClaudeCode = import ../../mcp/config.nix {
        nixpkgsInput = inputs.nixpkgs;
        mcpServersNixInput = inputs.mcp-servers-nix;
        system = pkgs.system;
        flavor = "claude";
        fileName = ".mcp.json";
      };
      # GitHub MCP server wrapper (reads token from sops secret at runtime)
      run-github-mcp-server = pkgs.writeShellApplication {
        name = "run-github-mcp-server";
        text = ''
          GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.github_personal_access_token.path})
          export GITHUB_PERSONAL_ACCESS_TOKEN
          exec github-mcp-server "$@"
        '';
      };
    in
    {
      # Claude Code config
      home.file.".mcp.json".source = mcpConfigClaudeCode;

      # VSCode Cline config
      home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/.keep".text = "";
      home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json".source =
        mcpConfigVSCode;

      # GitHub MCP server wrapper
      home.packages = [ run-github-mcp-server ];
    };
}
