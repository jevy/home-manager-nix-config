# Git configuration
{ ... }:
{
  flake.modules.homeManager.git =
    { pkgs, lib, ... }:
    {
      programs.git = {
        enable = true;
        settings.user = {
          name = lib.mkDefault "jevin";
          email = lib.mkDefault "jevin@quickjack.ca";
        };
        settings = {
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
        };
      };

      programs.gh = {
        enable = true;
        settings = {
          git_protocol = "https";
          prompt = "enabled";
          aliases = {
            co = "pr checkout";
          };
        };
      };

      programs.difftastic = {
        enable = true;
        git.enable = true;
      };
    };
}
