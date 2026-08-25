# Yazi file manager (replaces ranger).
#
# Two outputs from one definition:
#
#   homeManager.yazi     -> Linux hosts  (zathura/imv/vlc/xdg-open, ripdrag)
#   homeManager.yaziMac  -> mac-work     (everything through `open`)
#
# Everything except the opener table, the drag plugin and the detach syntax is
# shared, so keys and sort behaviour stay identical across machines — muscle
# memory is the whole point of keeping these in one file. Launched the same way
# on both: `yazi`, or the `yy` wrapper that cds the shell to wherever you quit.
#
# What macOS deliberately does NOT get:
#   * drag.yazi / ripdrag — ripdrag is GTK4; even where it builds, a GTK drag
#     source cannot hand a file to a native Cocoa drop target, so <C-d> would
#     open a window that does nothing. The key is left unbound there.
#   * a per-mime opener table — macOS already keeps a user-level default-app
#     mapping (LaunchServices) and `open` honours it, so encoding a second
#     table here would just let this file and Finder's "Open With" disagree.
#     Only the text rules stay explicit, because those must reach neovide/
#     $EDITOR rather than whatever LaunchServices thinks owns .nix.
#   * setsid — not a macOS command. Detaching is yazi's own `orphan`/`--orphan`,
#     which both platforms already rely on; the Linux `setsid -f` is belt and
#     braces for X clients that re-parent themselves.
{ ... }:
let
  # Shared across both platforms. `opener`/`plugins`/`extraKeys` are the seams.
  mkYazi =
    {
      packages,
      plugins,
      opener,
      extraKeys,
    }:
    {
      home.packages = packages;

      programs.yazi = {
        enable = true;
        enableZshIntegration = true;
        shellWrapperName = "yy";

        inherit plugins;

        settings = {
          mgr = {
            show_hidden = false;
            sort_by = "mtime";
            sort_dir_first = false;
            sort_reverse = true;
          };

          inherit opener;

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
            # Open shell in current directory (detached — survives yazi exit).
            # Inherits yazi's cwd on both platforms; ghostty needs no --working-directory.
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
          ]
          ++ extraKeys;
        };
      };
    };
in
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
    mkYazi {
      packages = with pkgs; [
        ripdrag
        p7zip
      ];

      plugins = {
        compress = compressPlugin;
        drag = dragPlugin;
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

      extraKeys = [
        # Drag and drop (replaces ranger <C-d>). Linux only — see header.
        { on = [ "<C-d>" ]; run = "plugin drag"; desc = "Drag and drop"; }
      ];
    };

  flake.modules.homeManager.yaziMac =
    { pkgs, ... }:
    let
      compressPlugin = pkgs.fetchFromGitHub {
        owner = "KKV9";
        repo = "compress.yazi";
        rev = "46a6b9f02ff2f8aced466a1f01a3fe241f1cd45f";
        hash = "sha256-Mby185FCJY6nqHcHDQu+D5SLk+wGcyeUHK8yAvrd4TM=";
      };
    in
    mkYazi {
      # p7zip backs both the compress plugin and `ya pub extract`; yazi shells
      # out to `7z`, and macOS ships no archiver on PATH (Archive Utility is
      # GUI-only), so without this both `ec` and `ex` fail silently.
      packages = with pkgs; [ p7zip ];

      plugins = { compress = compressPlugin; };

      # `open` routes through LaunchServices, so "the app I already picked in
      # Finder" wins — Preview for PDFs/images, whatever owns the video, etc.
      # Every entry is a second choice on the same list, reachable with `O`.
      opener = {
        pdf = [
          { run = ''open "$@"''; orphan = true; desc = "Default app"; }
          { run = ''open -a Preview "$@"''; orphan = true; desc = "Preview"; }
        ];
        image = [
          { run = ''open "$@"''; orphan = true; desc = "Default app"; }
          { run = ''open -a Preview "$@"''; orphan = true; desc = "Preview"; }
        ];
        video = [
          { run = ''open "$@"''; orphan = true; desc = "Default app"; }
          { run = ''open -a QuickTime\ Player "$@"''; orphan = true; desc = "QuickTime"; }
        ];
        text = [
          { run = ''neovide "$@"''; orphan = true; desc = "Neovide"; }
          { run = ''$EDITOR "$@"''; block = true; desc = "Editor"; }
        ];
        fallback = [
          { run = ''open "$@"''; orphan = true; desc = "Default app"; }
          { run = ''$EDITOR "$@"''; block = true; desc = "Editor"; }
        ];
      };

      # No <C-d>: no working drag source on macOS (see header).
      extraKeys = [ ];
    };
}
