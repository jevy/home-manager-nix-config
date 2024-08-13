{
  config,
  pkgs,
  ...
}: {

  programs.git = {
    enable = true;
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    aliases = {
      st = "status";
    };
    extraConfig = {
      push.autoSetupRemote = true;
    };
    difftastic.enable = true;
  };
}
