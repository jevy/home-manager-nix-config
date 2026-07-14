# Hunk — review-first terminal diff viewer for agent-authored changesets
# (github:modem-dev/hunk). Not in nixpkgs — vimPlugins.hunk-nvim is an
# unrelated julienvincent plugin — so consumed via upstream's flake, which
# ships its own home-manager module.
{ inputs, ... }:
{
  flake.modules.homeManager.hunk = {
    imports = [ inputs.hunk.homeManagerModules.default ];
    programs.hunk = {
      enable = true;
      # Sets hunk as the default git pager; requires programs.git.enable
      # (provided by the git module on every host that imports this).
      enableGitIntegration = true;
    };
  };
}
