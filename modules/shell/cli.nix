# CLI tools (cross-platform)
{ inputs, ... }:
{
  # Base CLI tools (all platforms)
  flake.modules.homeManager.cliBase =
    { config, pkgs, lib, ... }:
    {
      home.packages = with pkgs; [
        wget
        fastfetch
        git
        speedtest-cli
        k9s
        kubectl
        ripgrep
        ripgrep-all
        ast-grep
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
        ocrmypdf
        texliveSmall # texlive.combined schemes are deprecated, removal in nixpkgs 27.05
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
        (pkgs.callPackage ../../pkgs/linecast.nix { })
      ];

      programs.bat.enable = true;

      home.sessionVariables = {
        VAGRANT_DEFAULT_PROVIDER = "libvirt";
      };

      home.shellAliases = {
        l = "ls -l";
        lt = "ls --tree";
        la = "ls -a";
        geoip = "curl ifconfig.co/json";
        # Was a wttr.in curl, duplicated in cliLinux and desktopMac. linecast
        # is in cliBase, so one cross-platform alias replaces both.
        weather = "linecast weather";
        # Pinned to Ottawa. linecast geocodes the IATA code, so `--location
        # YOW` beats coordinates for readability; bare weather geolocates.
        wyow = "linecast weather --location YOW";
        lg = "lazygit";
        lhead = "ls --sort created -r | head";
        # Machine-aware rebuild. Lives in cliBase (imported by every host) so it
        # works on the Mac too — NixOS hosts rebuild the whole system; the Mac
        # runs nix-darwin, so switch its darwinConfiguration by name.
        rebuildhm =
          if pkgs.stdenv.isDarwin then
            "cd ~/.config/nixpkgs && sudo darwin-rebuild switch --flake \".#mac-work\""
          else
            "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake \".#$(hostname)\"";
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
          # inputs.typestream.packages.${pkgs.stdenv.hostPlatform.system}.typestream # TODO: upstream flake still references buildGo124Module (checked 2026-07-27; v0.4.1 released but flake untouched) — needs our own override or an upstream fix
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

      programs.zsh.initContent = ''
        export INNGEST_PROD_KEY=$(cat "${config.sops.secrets.inngest_prod_key.path}")

        # Exit-node switcher backing the tailscale-* aliases below.
        #
        # Two things bit the old hardcoded aliases:
        #   1. --exit-node resolves peer names against the *live netmap*. When
        #      tailscaled is stopped there is no netmap, so even a valid name
        #      fails with "must be IP or peer hostname". Hence the up-first guard.
        #   2. Mullvad retires and renumbers servers, so pinning one hostname
        #      (ca-tor-wg-001) is a time bomb. Match a region and pick a live
        #      node instead.
        ts-exit() {
          local re="$1" node ip
          if [ "$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState)" != "Running" ]; then
            sudo ${pkgs.tailscale}/bin/tailscale up --accept-routes --accept-dns || return 1
          fi
          if [ -z "$re" ]; then
            sudo ${pkgs.tailscale}/bin/tailscale set --exit-node= && echo "exit node cleared"
            return
          fi
          # ExitNodeOption filters out peers that do not actually advertise one
          # (octoprint, the old tailscale-home target, never did).
          node=$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r --arg re "$re" \
            '.Peer | to_entries[] | .value
             | select(.ExitNodeOption)
             | select(.DNSName | test($re))
             | "\(.DNSName | rtrimstr("."))\t\(.TailscaleIPs[0])"' | shuf -n1)
          if [ -z "$node" ]; then
            echo "no live exit node matching /$re/" >&2
            return 1
          fi
          ip=''${node##*$'\t'}
          sudo ${pkgs.tailscale}/bin/tailscale set --exit-node="$ip" \
            && echo "exit node: ''${node%%$'\t'*}"
        }
      '';

      home.shellAliases = {
        # dream-machine-pro is the only tailnet peer advertising an exit node.
        tailscale-home = "ts-exit 'dream-machine-pro'";
        tailscale-us = "ts-exit '^us-.*mullvad'";
        tailscale-toronto = "ts-exit '^ca-tor-.*mullvad'";
        tailscale-off = "ts-exit ''";
        fdt = "f(){ fd $1 -t file -X ls -tr -l; };f";
      };
    };
}
