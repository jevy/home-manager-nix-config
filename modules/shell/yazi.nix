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
        shellWrapperName = "yy";

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
              { run = ''zathura "$@"''; orphan = true; desc = "Zathura"; }
              { run = ''papers "$@"''; orphan = true; desc = "Papers"; }
              { run = ''firefox "$@"''; orphan = true; desc = "Firefox"; }
            ];
            image = [
              { run = ''imv "$@"''; orphan = true; desc = "imv"; }
              { run = ''gimp "$@"''; orphan = true; desc = "GIMP"; }
            ];
            video = [
              { run = ''vlc "$@"''; orphan = true; desc = "VLC"; }
              { run = ''firefox "$@"''; orphan = true; desc = "Firefox"; }
            ];
            text = [
              { run = ''setsid -f neovide "$@"''; orphan = true; desc = "Neovide"; }
              { run = ''$EDITOR "$@"''; block = true; desc = "Editor"; }
            ];
            fallback = [
              { run = ''xdg-open "$@"''; orphan = true; desc = "xdg-open"; }
              { run = ''setsid -f neovide "$@"''; orphan = true; desc = "Neovide"; }
              { run = ''$EDITOR "$@"''; block = true; desc = "Editor"; }
            ];
          };

          open.rules = [
            { url = "*.{toml,yaml,yml,json,nix,conf,cfg,ini,sh,bash,zsh,lua,py,rb,rs,go,js,ts,tsx,jsx,md,txt,log,env,css,html,xml,svg,sql,graphql,proto,tf,hcl,Makefile,Dockerfile}"; use = "text"; }
            { mime = "application/pdf"; use = "pdf"; }
            { mime = "image/*"; use = "image"; }
            { mime = "video/*"; use = "video"; }
            { mime = "audio/*"; use = "fallback"; }
            { mime = "text/*"; use = "text"; }
            { mime = "*"; use = "fallback"; }
          ];
        };

        keymap = {
          mgr.prepend_keymap = [
            # Extract archive (replaces ranger `ex`).
            # NOTE: must go through `ya pub extract`, not `plugin extract` —
            # the native extract plugin is pub/sub based (ps.sub_remote), so a
            # bare `plugin extract` just subscribes and blocks forever.
            { on = [ "e" "x" ]; run = ''shell 'ya pub extract --list "$@"' ''; desc = "Extract archive"; }
            # Compress selection (replaces ranger `ec`)
            { on = [ "e" "c" ]; run = "plugin compress"; desc = "Compress selection"; }
            # Recursive fzf search across subdirs (like ranger <C-f>)
            { on = [ "<C-f>" ]; run = ''shell 'result="$(fd -H | fzf)"; [ -n "$result" ] && ya emit reveal "$result"' --block''; desc = "fzf search"; }
            # Drag and drop (replaces ranger <C-d>)
            { on = [ "<C-d>" ]; run = "plugin drag"; desc = "Drag and drop"; }
            # Open shell in current directory (detached — survives yazi exit)
            { on = [ "w" ]; run = ''shell "ghostty" --orphan''; desc = "Open shell here"; }
            # Refresh directory (useful for NFS/network mounts where inotify doesn't fire)
            { on = [ "R" ]; run = "refresh"; desc = "Refresh directory"; }
            # Go to ~/Documents
            { on = [ "g" "D" ]; run = "cd ~/Documents"; desc = "Go to Documents"; }
            # Go to ~/code
            { on = [ "g" "e" ]; run = "cd ~/code"; desc = "Go to code"; }
            # Sorting
            { on = [ "," "m" ]; run = "sort modified --reverse"; desc = "Sort by modified"; }
            { on = [ "," "n" ]; run = "sort alphabetical"; desc = "Sort by name"; }
            { on = [ "," "d" ]; run = "sort dir-first --reverse"; desc = "Toggle dirs first"; }
          ];
        };
      };
    };
}
