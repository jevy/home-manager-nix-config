# CLI tools (cross-platform)
{ ... }:
{
  # Base CLI tools (all platforms)
  flake.modules.homeManager.cliBase =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        wget
        fastfetch
        ranger
        git
        speedtest-cli
        k9s
        kubectl
        ripgrep
        ripgrep-all
        file
        ffmpeg
        killall
        dig
        ldns
        unzip
        fzf
        yt-dlp
        termdown
        httpie
        kubectx
        pandoc
        texlive.combined.scheme-small
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
        aichat
        sops
        age
        awscli2
        devenv
        repomix
        poppler-utils
        bc
      ];

      programs.bat.enable = true;

      home.sessionVariables = {
        VAGRANT_DEFAULT_PROVIDER = "libvirt";
      };

      home.file.".config/ranger".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixpkgs/ranger";

      home.shellAliases = {
        l = "ls -l";
        lt = "ls --tree";
        la = "ls -a";
        geoip = "curl ifconfig.co/json";
        lg = "lazygit";
        lhead = "ls --sort created -r | head";
      };
    };

  # Linux-specific CLI tools
  flake.modules.homeManager.cliLinux =
    { config, pkgs, ... }:
    let
      ask-script = pkgs.stdenv.mkDerivation {
        name = "ask-unwrapped";
        src = pkgs.fetchFromGitHub {
          owner = "kagisearch";
          repo = "ask";
          rev = "master";
          sha256 = "sha256-3q9WWhDXmdDouLRHKp14F+FeSPG1IoCL4jVbcHJdtnk=";
        };
        installPhase = ''
          mkdir -p $out/bin
          cp ask $out/bin/
        '';
      };
    in
    {
      home.packages =
        with pkgs;
        [
          imagemagickBig
          mlocate
          usbutils
          kitty
          btop
          xan
          bashmount
          ncdu
          grpcurl
          dysk
          volsync
        ]
        ++ [
          (pkgs.writeShellApplication {
            name = "ask";
            runtimeInputs = [ ask-script ];
            text = ''
              OPENROUTER_API_KEY=$(cat "${config.sops.secrets.openrouter_api_key.path}")
              export OPENROUTER_API_KEY
              exec ask "$@"
            '';
          })
        ];

      programs.kitty = {
        enable = true;
        keybindings = {
          "shift+page_up" = "scroll_page_up";
          "shift+page_down" = "scroll_page_down";
        };
        settings = {
          scrollback_lines = 10000;
          enable_audio_bell = false;
          visual_bell_duration = "0.1";
        };
      };

      home.shellAliases = {
        rebuildhm = "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake '.#framework'";
        weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";
        fdt = "f(){ fd $1 -t file -X ls -tr -l; };f";
      };
    };
}
