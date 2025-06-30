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

    secrets.openai_api_key = {};
    secrets.anthropic_api_key = {};
    secrets.gemini_api_key = {};
    secrets.github_personal_access_token = {};
  };

  home.file.".config/zsh/api_keys.zsh" = {
    executable = true;
    text = ''
      export OPENAI_API_KEY=$(cat ${config.sops.secrets.openai_api_key.path})
      export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets.anthropic_api_key.path})
      export GEMINI_API_KEY=$(cat ${config.sops.secrets.gemini_api_key.path})
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.github_personal_access_token.path})
    '';
  };
}
