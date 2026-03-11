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
}
