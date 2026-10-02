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
#
# Opener/`shell` argument syntax: `%s` (selected files, hovered if none), NOT
# the old `"$@"`. Yazi deprecated `$n`/`$@` in favour of its own formatter
# (upstream #3232) and the compat shim is broken for the quoted form: with
# `zathura "$@"` the child is spawned with ZERO arguments, so zathura / papers /
# imv / vlc all came up empty. `%s` is escaped by yazi itself, so paths with
# spaces need no quoting here.
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
            { on = [ "e" "x" ]; run = ''shell 'ya pub extract --list %s' ''; desc = "Extract archive"; }
            # Compress selection (replaces ranger `ec`).
            # NOTE: the compress plugin rev must track yazi's `fs` API. Yazi 26
            # renamed `fs.unique_name` -> `fs.unique`, and the plugin's call to
            # the now-nil `fs.unique_name` does not surface as an error: the
            # plugin task just never finishes, so the "Create archive:" prompt
            # accepts a name and then nothing happens — no archive, no message,
            # and `q` only gets you the "unfinished tasks" dialog. Pin >= the
            # upstream `fs.unique` fix (748ebf3) whenever yazi is bumped.
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
        rev = "80e5268ec74c7ac17d4d739e13a9958cba4c70d3";
        hash = "sha256-9cdA8D/TtwHcLqrtoyIixA0YJmTs+c8FSNrjxp8CYI0=";
      };
      # `markup img.png` -> swappy (the same arrows/text/blur tool that the
      # Print screenshot binding uses). `-o` makes swappy write the result to
      # img-markup.png next to the original when the window closes, so the
      # marked-up copy stays beside its source instead of only landing in
      # ~/Screenshots. Ctrl+S still also saves there (swappy config save_dir)
      # and Ctrl+C copies to the clipboard. The original is never overwritten.
      # Closing without drawing still writes an (identical) -markup copy.
      # Several files open one after another; swappy -f takes only one.
      markup = pkgs.writeShellApplication {
        name = "markup";
        runtimeInputs = [ pkgs.swappy ];
        text = ''
          [ $# -gt 0 ] || { echo "usage: markup IMAGE..." >&2; exit 1; }
          for f in "$@"; do
            swappy -f "$f" -o "''${f%.*}-markup.png"
          done
        '';
      };
      # `c b` in yazi: copy the selected paths, one per line, each wrapped in
      # backticks. Plain `c c` paths of images get swallowed by Claude Code's
      # prompt: on paste it splits the text on newlines (and on a space before
      # `/`), strips surrounding '"' / "'" quotes, and any piece ending in
      # .png/.jpe?g/.gif/.webp that exists on disk becomes an [Image #N]
      # attachment (regex /\.(png|jpe?g|gif|webp)$/i, read from the 2.1.283
      # binary). Quotes are stripped first so they don't help; a trailing
      # backtick fails the `$` anchor, so the paste stays text.
      copyPathsBackticked = pkgs.writeShellApplication {
        name = "yazi-copy-paths-backticked";
        runtimeInputs = [ pkgs.wl-clipboard ];
        # SC2016: the backticks are literal output, not command substitution.
        excludeShellChecks = [ "SC2016" ];
        text = ''
          for f in "$@"; do printf '`%s`\n' "$f"; done | wl-copy -n
        '';
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
        markup
        copyPathsBackticked
      ];

      plugins = {
        compress = compressPlugin;
        drag = dragPlugin;
      };

      opener = {
        pdf = [
          { run = ''zathura %s''; orphan = true; desc = "Zathura"; }
          { run = ''papers %s''; orphan = true; desc = "Papers"; }
          { run = ''firefox %s''; orphan = true; desc = "Firefox"; }
        ];
        image = [
          { run = ''imv %s''; orphan = true; desc = "imv"; }
          { run = ''markup %s''; orphan = true; desc = "Mark up (swappy)"; }
          { run = ''gimp %s''; orphan = true; desc = "GIMP"; }
        ];
        # mpv leads, not VLC. ashell owns org.kde.StatusNotifierWatcher and
        # its handler stops answering once a tray client registers, while the
        # bus name stays claimed, so Qt's tray probe during platform init gets
        # no reply and runs into D-Bus's 25s default timeout. VLC decodes the
        # file immediately but shows no window for 25s. mpv is not a Qt app and
        # never probes the watcher, so it opens instantly. VLC stays as the
        # second choice on `O`. See modules/desktop/ashell.nix for the wedge
        # itself and the watchdog that papers over it; drop this ordering once
        # ashell stops wedging (unfixed as of 0.10.0, tray dbus.rs untouched
        # since 2026-06-27).
        video = [
          { run = ''mpv %s''; orphan = true; desc = "mpv"; }
          { run = ''vlc %s''; orphan = true; desc = "VLC"; }
          { run = ''firefox %s''; orphan = true; desc = "Firefox"; }
        ];
        text = [
          { run = ''setsid -f neovide %s''; orphan = true; desc = "Neovide"; }
          { run = ''$EDITOR %s''; block = true; desc = "Editor"; }
        ];
        fallback = [
          { run = ''xdg-open %s''; orphan = true; desc = "xdg-open"; }
          { run = ''setsid -f neovide %s''; orphan = true; desc = "Neovide"; }
          { run = ''$EDITOR %s''; block = true; desc = "Editor"; }
        ];
      };

      extraKeys = [
        # Drag and drop (replaces ranger <C-d>). Linux only — see header.
        { on = [ "<C-d>" ]; run = "plugin drag"; desc = "Drag and drop"; }
        # Mark up image with swappy (also the second entry on `O` for images).
        { on = [ "e" "m" ]; run = ''shell 'markup %s' --orphan''; desc = "Mark up image"; }
        # Copy paths in `backticks` so Claude Code keeps them as text (see above).
        { on = [ "c" "b" ]; run = ''shell 'yazi-copy-paths-backticked %s' ''; desc = "Copy paths (backticked, for Claude Code)"; }
      ];
    };

  flake.modules.homeManager.yaziMac =
    { pkgs, ... }:
    let
      compressPlugin = pkgs.fetchFromGitHub {
        owner = "KKV9";
        repo = "compress.yazi";
        rev = "80e5268ec74c7ac17d4d739e13a9958cba4c70d3";
        hash = "sha256-9cdA8D/TtwHcLqrtoyIixA0YJmTs+c8FSNrjxp8CYI0=";
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
          { run = ''open %s''; orphan = true; desc = "Default app"; }
          { run = ''open -a Preview %s''; orphan = true; desc = "Preview"; }
        ];
        image = [
          { run = ''open %s''; orphan = true; desc = "Default app"; }
          { run = ''open -a Preview %s''; orphan = true; desc = "Preview"; }
        ];
        video = [
          { run = ''open %s''; orphan = true; desc = "Default app"; }
          { run = ''open -a QuickTime\ Player %s''; orphan = true; desc = "QuickTime"; }
        ];
        text = [
          { run = ''neovide %s''; orphan = true; desc = "Neovide"; }
          { run = ''$EDITOR %s''; block = true; desc = "Editor"; }
        ];
        fallback = [
          { run = ''open %s''; orphan = true; desc = "Default app"; }
          { run = ''$EDITOR %s''; block = true; desc = "Editor"; }
        ];
      };

      # No <C-d>: no working drag source on macOS (see header).
      extraKeys = [ ];
    };
}
