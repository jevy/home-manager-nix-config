# Claude Code AI coding agent
{ inputs, ... }:
{
  flake.modules.homeManager.claudeCode =
    { pkgs, ... }:
    let
      claude-code-router = pkgs.callPackage ../../pkgs/claude-code-router.nix { };
    in
    {
      home.packages = [
        pkgs.claude-code
        claude-code-router
      ];
    };

  # Separate, opt-in module: merge programs.mcp.servers into Claude Code's own
  # config. Deliberately NOT in the claudeCode module above — the upstream HM
  # module writes ~/.claude/settings.json whenever MCP integration is enabled
  # (to emit disabledMcpjsonServers), which would clobber the hand-maintained
  # global settings.json (permissions/hooks/plugins/autoMode). Only import this
  # on hosts whose settings.json has been migrated into the module's
  # `settings` option. Server sets stay per-host via local.mcp.only in mcp.nix.
  flake.modules.homeManager.claudeCodeMcp =
    { ... }:
    {
      programs.claude-code.enableMcpIntegration = true;
    };
}
