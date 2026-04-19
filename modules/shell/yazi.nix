# Yazi file manager (replaces ranger)
{ ... }:
{
  flake.modules.homeManager.yazi =
    { pkgs, ... }:
    let
      compressPlugin = pkgs.fetchFromGitHub {
        owner = "KKV9";
        repo = "compress.yazi";
        rev = "46a6b9f02ff2f8aced466a1f01a3fe241f1cd45f";
        hash = "sha256-Mby185FCJY6nqHcHDQu+D5SLk+wGcyeUHK8yAvrd4TM=";
      };
      dragPlugin = pkgs.fetchFromGitHub {
        owner = "Joao-Queiroga";
        repo = "drag.yazi";
        rev = "3dff129c52b30d8c08015e6f4ef8f2c07b299d4b";
        hash = "sha256-nmFlh+zW3aOU+YjbfrAWQ7A6FlGaTDnq2N2gOZ5yzzc=";
      };
    in
    {
      home.packages = with pkgs; [
        ripdrag
        p7zip
      ];

      programs.yazi = {
        enable = true;
        enableZshIntegration = true;

        plugins = {
          compress = compressPlugin;
          drag = dragPlugin;
        };

        settings = {
          mgr = {
            show_hidden = false;
            sort_by = "mtime";
            sort_dir_first = false;
            sort_reverse = true;
          };

          opener = {
            pdf = [
              { run = ''zathura "$@"''; desc = "Zathura"; }
              { run = ''papers "$@"''; desc = "Papers"; }
              { run = ''firefox "$@"''; desc = "Firefox"; }
            ];
            image = [
              { run = ''imv "$@"''; desc = "imv"; }
              { run = ''gimp "$@"''; desc = "GIMP"; }
            ];
            video = [
              { run = ''vlc "$@"''; desc = "VLC"; }
              { run = ''firefox "$@"''; desc = "Firefox"; }
            ];
            text = [
              { run = ''$EDITOR "$@"''; block = true; desc = "Editor"; }
            ];
            fallback = [
              { run = ''xdg-open "$@"''; desc = "xdg-open"; }
            ];
          };

          open.rules = [
            { mime = "application/pdf"; use = "pdf"; }
            { mime = "image/*"; use = "image"; }
            { mime = "video/*"; use = "video"; }
            { mime = "audio/*"; use = "fallback"; }
            { mime = "text/*"; use = "text"; }
            { name = "*.{toml,yaml,yml,json,nix,conf,cfg,ini,sh,bash,zsh,lua,py,rb,rs,go,js,ts,md,txt,log,env}"; use = "text"; }
            { mime = "*"; use = "fallback"; }
          ];
        };

        keymap = {
          mgr.prepend_keymap = [
            # Extract archive (replaces ranger `ex`)
            { on = [ "e" "x" ]; run = "plugin extract"; desc = "Extract archive"; }
            # Compress selection (replaces ranger `ec`)
            { on = [ "e" "c" ]; run = "plugin compress"; desc = "Compress selection"; }
            # Recursive fzf search across subdirs (like ranger <C-f>)
            { on = [ "<C-f>" ]; run = ''shell 'result="$(fd -H | fzf)"; [ -n "$result" ] && ya emit reveal "$result"' --block''; desc = "fzf search"; }
            # Drag and drop (replaces ranger <C-d>)
            { on = [ "<C-d>" ]; run = "plugin drag"; desc = "Drag and drop"; }
          ];
        };
      };
    };
}
