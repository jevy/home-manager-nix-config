# Claude Code AI coding agent
{ inputs, ... }:
{
  # Pin claude-code to specific version (nixpkgs lags behind)
  flake.overlays.claudeCode = final: prev: {
    claude-code = prev.claude-code.overrideAttrs (old: rec {
      version = "2.1.42";
      src = prev.fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
        hash = "sha256-+99eaqKAOUvz+omHJ4bxlDepdpn8FNLmvxKcVDR76o4=";
      };
      npmDepsHash = "sha256-2if3LsTEnC2OQjEgojqgzs8YOXdpoqJijEmVlxmEfzw=";
    });
  };

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
