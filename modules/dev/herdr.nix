# herdr — terminal workspace manager for AI coding agents (panes, tabs, agents,
# worktrees), plus two plugins that split the review work between them:
#   pickr   — Ctrl+click an *open* PR/MR link → pick a reviewer (tuicr posts
#             comments back to the forge).
#   reviewr — sidebar over the *local* diff an agent just wrote; `s` sends line
#             comments back to the agent's input. Its PR tab is read-only, which
#             is why pickr stays: only tuicr can submit a review to the forge.
#
# Not in nixpkgs, and upstream's flake ships packages only (no home-manager
# module), so the package comes straight off the flake input.
#
# ── Hotkeys ──────────────────────────────────────────────────────────────────
# All of these are upstream *defaults*: config.toml is unmanaged (see the bottom
# of this header), so nothing here rebinds them. `herdr --default-config` prints
# the authoritative list; `prefix+?` shows it in-app.
#
# Prefix is ctrl+b. "prefix+x" means ctrl+b then x — not a simultaneous chord.
#
#   Tabs (within a workspace)
#     prefix+c          new tab
#     prefix+n          next tab            prefix+p        previous tab
#     prefix+1..9       jump to tab N
#     prefix+shift+t    rename              prefix+shift+x  close
#
#   Workspaces (one per repo/task; each holds its own tabs)
#     prefix+w          workspace picker  ← the main way to move between them
#     prefix+shift+n    new workspace       prefix+shift+g  new worktree
#     prefix+shift+w    rename              prefix+shift+d  close
#     prefix+g          goto (navigate mode; then h/j/k/l or arrows)
#   Note: previous_workspace / next_workspace / switch_workspace ship UNBOUND.
#   For direct ctrl+shift+1..9 switching, set keys.indexed.workspaces.
#
#   Panes — i.e. moving between the agent and a review pane (tuicr, reviewr, hunk)
#     prefix+h/j/k/l    focus pane left/down/up/right
#     prefix+tab        cycle panes         prefix+shift+tab  cycle backwards
#     prefix+z          zoom/unzoom the focused pane  ← best way to read a diff
#                       full-screen, then pop back to the agent
#     prefix+v          split vertical      prefix+minus      split horizontal
#     prefix+x          close pane          prefix+r          resize mode
#     prefix+b          toggle sidebar
#   last_pane ships UNBOUND; bind it (e.g. prefix+tab) for fast agent↔review
#   flip-flopping, which is the motion this setup uses most.
#
#   Inside the review tools themselves
#     pickr chooser     t tuicr · h hunk · d plain diff · o browser · q cancel
#     tuicr             c line comment · C file comment · <leader>c review
#                       comment · m/M next/prev comment · :e reload the diff
#                       (tuicr does NOT auto-reload) · q quit
#     reviewr           u/b/t scope (uncommitted/branch/last-turn) · v select ·
#                       c comment · s send all comments to the agent · r refresh
#                       · 1/2/3 tabs (Changes/All Files/PR) · q quit
#     hunk              q quit; launch with `hunk diff --watch` to auto-reload
#                       as the agent edits
#
# ── Plugins ──────────────────────────────────────────────────────────────────
# herdr has no declarative plugin option: `herdr plugin install owner/repo`
# git-clones into ~/.config/herdr/plugins/github and registers the checkout in
# ~/.config/herdr/plugins.json, which herdr rewrites at runtime (enable/disable).
# That registry can't be a read-only home.file symlink, so plugins land the other
# way round: Nix stages each plugin directory into the store (pkgs/herdr-pickr.nix,
# pkgs/herdr-reviewr.nix) and activation calls `herdr plugin link <store-path>`,
# which registers a local path without cloning or running build hooks. `link`
# replaces any existing entry for the same plugin id, so re-running it every
# activation is idempotent and repoints the registry at the new store path after
# an input bump — including over an entry left by an imperative
# `herdr plugin install`, since both resolve to the same manifest `id`.
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
      herdr-reviewr = pkgs.callPackage ../../pkgs/herdr-reviewr.nix { src = inputs.herdr-reviewr; };

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

      # reviewr's own config. Themed to match stylix's gruvbox-material-dark-soft.
      reviewrConfig = ''
        theme = "gruvbox"

        # Open on what the agent changed this turn rather than the whole worktree.
        # Caveat: last-turn tracking polls (~2s), so a turn that starts and ends
        # inside one poll is missed and the scope can span several turns — press
        # `u` for the plain uncommitted diff to cross-check.
        default_scope = "last-turn"

        navigator_position = "right"
        toggle_placement = "split"
        toggle_direction = "right"

        # Upstream defaults this to true, which pops the pane on every
        # worktree.created event. Off here: herdr worktrees get created often
        # enough that auto-opening is more interruption than help. The pane is a
        # keybind away — see the toggle note below.
        auto_open = false
      '';
    in
    {
      # pickr's reviewer rows need tuicr / gh / hunk / bat on PATH; those come
      # from the tuicr, git (programs.gh), hunk and cliBase (programs.bat)
      # modules, which every host importing this one also imports.
      home.packages = [ herdr ];

      # ~/.config/herdr/plugins/config/<id>/ — the id maps to the directory name
      # verbatim (lowercase ASCII ids pass through unescaped), so reviewr's
      # dotted id becomes a literal `persiyanov.reviewr` directory.
      xdg.configFile."herdr/plugins/config/pickr/config.toml".text = pickrConfig;
      xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".text = reviewrConfig;

      # Registers (or re-points) each plugin. Works with no herdr server running:
      # the CLI falls back to writing plugins.json directly. Non-fatal — when a
      # herdr server from a previous version is still running, `link` is routed
      # through its socket and can fail on a protocol mismatch, which shouldn't
      # take the whole switch down; restarting herdr and re-running fixes it.
      #
      # Auto-route (skip the chooser) is toggled by pickr.toggle-auto, and
      # reviewr's pane by persiyanov.reviewr.toggle. Both need a keybind in
      # ~/.config/herdr/config.toml — unmanaged here, see the header:
      #   [[keys.command]]
      #   key = "prefix+alt+v"
      #   type = "plugin_action"
      #   command = "persiyanov.reviewr.toggle"
      home.activation.herdrPluginLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-pickr} \
          || warnEcho "herdr: failed to link the herdr-pickr plugin"
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-reviewr} \
          || warnEcho "herdr: failed to link the herdr-reviewr plugin"
      '';
    };
}
