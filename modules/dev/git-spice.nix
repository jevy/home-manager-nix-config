# git-spice — stacked branches/PRs on top of git (`gs` CLI, nixpkgs package).
# home-manager has no programs.git-spice module (checked); git-spice reads its
# config from git config (spice.* keys), so the package is all that's needed.
{
  flake.modules.homeManager.gitSpice =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.git-spice ];
    };
}
