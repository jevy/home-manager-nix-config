{
  config,
  pkgs,
  libs,
  ...
}: let
  customRanger = pkgs.ranger.override {
    neoVimSupport = true;
    imagePreviewSupport = true;
  };
  ask = pkgs.stdenv.mkDerivation {
    name = "ask";
    src = pkgs.fetchFromGitHub {
      owner = "kagisearch";
      repo = "ask";
      rev = "master";
      sha256 = "sha256-H2/H41A+iW89iG4j/vjB4gX9X1Y2Z3z4y5f6g7h8i9o="; # This will need to be updated
    };
    installPhase = ''
      mkdir -p $out/bin
      cp ask $out/bin/
    '';
  };
in {
  home.packages = with pkgs; [
    wget
    fastfetch
    ranger
    git
    speedtest-cli
    unstable.k9s
    kubectl
    ripgrep
    ripgrep-all
    file
    ffmpeg
    killall
    dig
    ldns # drill
    unzip
    fzf # For ranger
    yt-dlp
    termdown
    httpie
    kubectx
    pandoc
    texlive.combined.scheme-full
    zip
    fd
    feh
    curl
    tree
    gh
    csvlens
    superfile
    lazygit
    jq
    doggo
    tre-command
    unstable.aichat
    sops # Encryption
    age # Encryption
    awscli2
    unstable.devenv
    ask
    bc
  ];

  programs.bat = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    historyLimit = 10000;
    # focusEvents = true; # Only in HM 25.05 +
    escapeTime = 200;
    mouse = true;
    shortcut = "a";
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
    ];
    extraConfig = ''
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %
      set-option -g display-time 0
    '';
  };

  home.sessionVariables = {
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
    OPENROUTER_API_KEY = config.sops.secrets.openrouter_api_key.path;
  };

  home.file = {
    ".config/ranger".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixpkgs/ranger";
  };

  home.shellAliases = {
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";

    fdt = "f() fd $1 -t file -X ls -tr -l);f"; # Search files sort by date

    geoip = "curl ifconfig.co/json";

    rebuildhm = "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake '.#x86_64-linux'";

    weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";

    lg = "lazygit";

    lhead = "ls --sort created -r | head";
  };
}
