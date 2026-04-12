# CLI tools (cross-platform)
{ inputs, ... }:
{
  # Base CLI tools (all platforms)
  flake.modules.homeManager.cliBase =
    { config, pkgs, lib, ... }:
    let
      rangerArchives = pkgs.fetchFromGitHub {
        owner = "maximtrp";
        repo = "ranger-archives";
        rev = "4085d338b87c3e6cb5f90b532740bff3a18f68ac";
        sha256 = "sha256-D1w+RsorEoZx91r8Wb8RvNMgLhikflA4uG2jgcRZhGc=";
      };
    in
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
        csvlens
        superfile
        lazygit
        jq
        numr
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
        sqlite
        uv # needed for linkedin-mcp profile creation
        google-cloud-sdk
      ];

      programs.bat.enable = true;

      home.sessionVariables = {
        VAGRANT_DEFAULT_PROVIDER = "libvirt";
      };

      home.file.".config/ranger/rc.conf".source = ../../ranger/rc.conf;
      home.file.".config/ranger/commands.py".source = ../../ranger/commands.py;
      home.file.".config/ranger/rifle.conf".source = ../../ranger/rifle.conf;
      home.file.".config/ranger/scope.sh".source = ../../ranger/scope.sh;
      home.file.".config/ranger/plugins/ranger-archives".source = rangerArchives;

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
          rev = "f9c79b668f457183f8278ebf93aab5c1391575e3";
          sha256 = "sha256-0RzJw3iQLig1BDszdstC7qyycQjVcE/FYC/N5jsUFIc=";
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
          (btop.override { rocmSupport = true; })
          xan
          bashmount
          ncdu
          grpcurl
          dysk
          # inputs.typestream.packages.${pkgs.stdenv.hostPlatform.system}.typestream # TODO: fix buildGo124Module in upstream
          inputs.llmfit.packages.${pkgs.stdenv.hostPlatform.system}.default
          volsync
          (pkgs.callPackage ../../pkgs/sms-backup-md.nix { })
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
        rebuildhm = "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake \".#$(hostname)\"";
        weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";
        fdt = "f(){ fd $1 -t file -X ls -tr -l; };f";
      };
    };
}
