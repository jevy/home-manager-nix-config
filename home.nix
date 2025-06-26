{
  config,
  pkgs,
  ...
}: {
  # ixpkgs.config.allowUnfreePredicate = (pkg: true);

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.
  # programs.home-manager.enable = true;

  home.keyboard = {
    layout = "us";
    variant = "qwerty";
    options = ["ctrl:nocaps"];
  };
  programs.git = {
    enable = true;
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    difftastic.enable = true;
  };

  sops = {
    age.keyFile = "/home/jevin/.config/sops/age/keys.txt"; # must have no password!

    defaultSopsFile = ./secrets.yaml;

    secrets.openai_api_key = {
      path = "${config.sops.defaultSymlinkPath}/openai_api_key";
    };
    secrets.anthropic_api_key = {
      path = "${config.sops.defaultSymlinkPath}/anthropic_api_key";
    };
    secrets.gemini_api_key = {
      path = "${config.sops.defaultSymlinkPath}/gemini_api_key";
    };
  };

  home.sessionVariables = {
    OPENAI_API_KEY = "$(cat ${config.sops.secrets.openai_api_key.path})";
    ANTHROPIC_API_KEY = "$(cat ${config.sops.secrets.anthropic_api_key.path})";
    GEMINI_API_KEY = "$(cat ${config.sops.secrets.gemini_api_key.path})";
  };
}
