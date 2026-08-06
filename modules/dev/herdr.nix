# herdr — terminal workspace manager for AI coding agents (panes, tabs, agents,
# worktrees), plus the herdr-pickr plugin for PR review routing.
#
# Not in nixpkgs, and upstream's flake ships packages only (no home-manager
# module), so the package comes straight off the flake input.
#
# ── Plugins ──────────────────────────────────────────────────────────────────
# herdr has no declarative plugin option: `herdr plugin install owner/repo`
# git-clones into ~/.config/herdr/plugins/github and registers the checkout in
# ~/.config/herdr/plugins.json, which herdr rewrites at runtime (enable/disable).
# That registry can't be a read-only home.file symlink, so plugins land the other
# way round: Nix stages the plugin directory into the store (pkgs/herdr-pickr.nix)
# and activation calls `herdr plugin link <store-path>`, which registers a local
# path without cloning or running build hooks. `link` replaces any existing entry
# for the same plugin id, so re-running it every activation is idempotent and
# repoints the registry at the new store path after an input bump.
#
# The plugin's own config IS declarative: herdr only creates
# ~/.config/herdr/plugins/config/<id>/ and never reads or writes what's inside,
# so config.toml is a plain home.file symlink.
#
# herdr's own config (~/.config/herdr/config.toml) is deliberately NOT managed
# here — herdr's Settings UI writes to it, and a read-only symlink would break
# that.
{ inputs, ... }:
{
  flake.modules.homeManager.herdr =
    { pkgs, lib, ... }:
    let
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
      herdr-pickr = pkgs.callPackage ../../pkgs/herdr-pickr.nix { src = inputs.herdr-pickr; };

      # pickr's `browser` reviewer shells out to the platform opener.
      opener = if pkgs.stdenv.hostPlatform.isDarwin then "open" else "xdg-open";

      # Reviewer rows. A row is hidden unless every binary in `needs` is on PATH,
      # and `platforms` gates it per forge. glab isn't installed on any host here,
      # so the gh-driven rows are GitHub-only and their run_gitlab lines are
      # omitted rather than left dead.
      pickrConfig = ''
        [pickr]
        auto    = false
        default = "tuicr"

        [[backend]]
        key = "t"
        id  = "tuicr"
        name = "tuicr — full review, comments to the forge"
        run  = "tuicr pr {url}"
        where = "pane"
        needs = ["tuicr"]
        platforms = ["github", "gitlab"]

        [[backend]]
        key = "h"
        id  = "hunk"
        name = "hunk — fast diff viewer"
        run_github = "gh pr diff {url} --no-color | hunk patch -"
        where = "pane"
        needs = ["gh", "hunk"]
        platforms = ["github"]

        [[backend]]
        key = "d"
        id  = "diff"
        name = "diff — plain read-only (bat)"
        run_github = "gh pr diff {url} | bat --paging=always -l diff"
        where = "pager"
        needs = ["gh", "bat"]
        platforms = ["github"]

        [[backend]]
        key = "o"
        id  = "browser"
        name = "open in browser"
        run  = "${opener} {url}"
        where = "detach"
        needs = []
        platforms = ["github", "gitlab"]
      '';
    in
    {
      # pickr's reviewer rows need tuicr / gh / hunk / bat on PATH; those come
      # from the tuicr, git (programs.gh), hunk and cliBase (programs.bat)
      # modules, which every host importing this one also imports.
      home.packages = [ herdr ];

      # ~/.config/herdr/plugins/config/pickr/ — the id maps to the directory name
      # verbatim (lowercase ASCII ids pass through unescaped).
      xdg.configFile."herdr/plugins/config/pickr/config.toml".text = pickrConfig;

      # Registers (or re-points) the plugin. Works with no herdr server running:
      # the CLI falls back to writing plugins.json directly. Non-fatal — when a
      # herdr server from a previous version is still running, `link` is routed
      # through its socket and can fail on a protocol mismatch, which shouldn't
      # take the whole switch down; restarting herdr and re-running fixes it.
      #
      # Auto-route (skip the chooser) is toggled by pickr.toggle-auto, which needs
      # a keybind in ~/.config/herdr/config.toml — unmanaged here, see the header.
      home.activation.herdrPickrLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-pickr} \
          || warnEcho "herdr: failed to link the herdr-pickr plugin"
      '';
    };
}
