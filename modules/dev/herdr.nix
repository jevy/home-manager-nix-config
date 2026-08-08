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
# Upstream defaults except where `herdrConfig` below overrides them (currently
# only prefix+j/k). `herdr --default-config` prints the authoritative default
# list; `prefix+?` shows the live bindings in-app.
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
#     prefix+j          next workspace      prefix+k        previous workspace
#   These two are ours (see herdrConfig): upstream ships previous_workspace /
#   next_workspace / switch_workspace UNBOUND, leaving only the prefix+w picker.
#   They take prefix+j/k from focus_pane_down/up, which cost nothing here —
#   splits are side-by-side, and navigate mode's j/k still move panes vertically
#   since navigate_* is independent of focus_pane_*.
#
#   Panes — i.e. moving between the agent and a review pane (tuicr, reviewr, hunk)
#     prefix+d          toggle the reviewr pane  ← ours; the only reviewer that
#                       works with no PR open. See the plugin action below.
#     prefix+tab        back to the previous pane  ← ours (last_pane); the
#                       agent↔review flip this setup uses most
#     prefix+h/l        focus pane left/right  (down/up unbound, see above)
#     prefix+shift+tab  cycle panes backwards (forward cycling gave up its key
#                       to last_pane — see herdrConfig)
#     prefix+z          zoom/unzoom the focused pane  ← best way to read a diff
#                       full-screen, then pop back to the agent
#     prefix+v          split vertical      prefix+minus      split horizontal
#     prefix+x          close pane          prefix+r          resize mode
#     prefix+b          toggle sidebar
#   GOTCHA: focus_pane_* only moves WITHIN the current tab. Agents here get a tab
#   each (one pane per tab), so prefix+h/l does nothing until a second pane exists
#   in that tab — which is exactly what a reviewr split gives you. To move between
#   agents, use the tab keys above, not the pane keys.
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
# ── herdr's own config ───────────────────────────────────────────────────────
# ~/.config/herdr/config.toml is generated (pkgs.formats.toml — nixpkgs has no
# pure `lib.generators.toTOML`) but installed as a WRITABLE COPY, not a symlink.
# herdr writes this file itself: the Settings UI, `config reset-keys`, and the
# `onboarding` flag all persist here, and it writes in place rather than
# temp+rename — so a store symlink makes every write fail with
# `Os { code: 30, kind: ReadOnlyFilesystem }` instead of silently replacing the
# link. Verified by pointing XDG_CONFIG_HOME at a symlinked copy and running
# `herdr config reset-keys`.
#
# The tradeoff of a copy: herdr may write to it freely between rebuilds, but each
# activation restores this file's content. Changes made through the Settings UI
# are therefore TRANSIENT — to keep one, add it here. Anything herdr must
# persist across a rebuild (notably `onboarding`) has to be declared below, or it
# resets every switch.
{ inputs, ... }:
{
  flake.modules.homeManager.herdr =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
      herdr-pickr = pkgs.callPackage ../../pkgs/herdr-pickr.nix { src = inputs.herdr-pickr; };
      herdr-reviewr = pkgs.callPackage ../../pkgs/herdr-reviewr.nix { src = inputs.herdr-reviewr; };

      # herdr's own config. TOML has no comment support once generated, so the
      # reasoning lives here rather than in the output file.
      herdrConfig = (pkgs.formats.toml { }).generate "herdr-config.toml" {
        # herdr writes this itself after the first run. It MUST be declared here:
        # activation replaces the file, so a missing value re-triggers onboarding
        # on every rebuild.
        onboarding = false;

        ui = {
          show_agent_labels_on_pane_borders = true;
          toast.delivery = "system";

          # Order the agent panel as an attention queue rather than grouping it
          # by space (upstream default "spaces"). With several agents running,
          # the useful question is "which one is waiting on me", and priority
          # floats blocked/done to the top instead of pinning each row to
          # wherever its space happens to sit.
          #
          # This was set through the Settings TUI first, which does NOT survive:
          # activation reinstalls config.toml from the store on every rebuild
          # (see the header). Declared here so it actually persists.
          agent_panel_sort = "priority";

          # Sidebar agent rows. Each inner list is one rendered line; tokens on a
          # line are joined with " · ". Built-in tokens: state_icon, state_text,
          # workspace, tab, pane, agent, terminal_title, terminal_title_stripped
          # (plus $name for anything a pane reports as custom metadata).
          #
          # Upstream default is [["state_icon" "workspace" "tab"] ["agent"]],
          # which drops state_text — so a row reads "claude" and the only signal
          # that an agent is blocked and waiting on you is the colour of the dot.
          # The status is always in the model (`herdr agent list` reports
          # agent_status idle/working/blocked/done); it just isn't rendered.
          # Spelling it out is the whole point of the panel when several agents
          # run at once.
          #
          # "$cwd" is NOT a built-in. herdr's built-in token list is closed —
          # state_icon, state_text, workspace, tab, pane, agent, terminal_title,
          # terminal_title_stripped — and there is no directory token in it, even
          # though the server tracks `cwd` and `foreground_cwd` per pane (see
          # `herdr pane get <id>`). The only way to render a value herdr doesn't
          # ship is to push it as pane metadata and reference it as $name; the
          # zsh hook in `herdrCwdHook` below is what supplies this one. If that
          # hook stops firing the row simply renders empty — it never errors.
          #
          # Worth the plumbing because `workspace` is a label, not a location:
          # every worktree of one repo can carry the same workspace name, and a
          # `wt`-style worktree lives at a path the name says nothing about.
          sidebar.agents = {
            rows = [
              [
                "state_icon"
                "workspace"
              ]
              [ "$cwd" ]
              [
                "state_text"
                "agent"
              ]
            ];

            # Claude sets its terminal title to a summary of the current task
            # ("Fix avahi-daemon service startup failure"), which disambiguates
            # two agents in the same repo far better than the workspace name —
            # every worktree of one repo otherwise renders an identical row.
            # Agents without an entry here fall back to `rows` above.
            rows_by_agent.claude = [
              [
                "state_icon"
                "workspace"
              ]
              [ "terminal_title_stripped" ]
              [ "$cwd" ]
              [
                "state_text"
                "agent"
              ]
            ];
          };
        };

        keys = {
          # Workspace switching on prefix+j/k. Upstream leaves
          # previous_workspace/next_workspace unbound, so the prefix+w picker is
          # otherwise the only way across. This takes the keys from
          # focus_pane_down/up, which is free here: splits are side-by-side, and
          # navigate mode (prefix+g) keeps j/k for vertical pane moves because
          # navigate_* is independent of focus_pane_*.
          focus_pane_down = "";
          focus_pane_up = "";
          next_workspace = "prefix+j";
          previous_workspace = "prefix+k";

          # Flip back to the pane you came from. Upstream ships this unbound,
          # leaving only cycle_pane_next here; last_pane is the better motion for
          # the two-pane agent↔review layout this setup lives in, since it
          # returns to the agent from anywhere instead of walking the ring.
          # Takes prefix+tab from cycle_pane_next — cycle_pane_previous
          # (prefix+shift+tab) still walks the ring when a tab has 3+ panes.
          cycle_pane_next = "";
          last_pane = "prefix+tab";

          # Plugin actions. "<plugin_id>.<action_id>"; `herdr plugin action list`
          # prints the live ids. pkgs.formats.toml renders a list of attrsets as
          # [[keys.command]].
          #
          # reviewr's pane is the only reviewer that works before a PR exists —
          # pickr's rows all interpolate a forge {url}. With auto_open = false it
          # otherwise has no keyboard entry point at all, so it gets prefix+d
          # ("diff"). Free in upstream's map: only prefix+shift+d (close
          # workspace) is taken.
          command = [
            {
              key = "prefix+d";
              type = "plugin_action";
              command = "persiyanov.reviewr.toggle";
            }
          ];
        };
      };

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

      # Supplies the $cwd sidebar token (see herdrConfig above). Pushed from the
      # shell rather than from an agent hook because it is agent-agnostic: any
      # pane running any tool reports its directory the same way, and the
      # ~/.claude, ~/.pi and ~/.config/opencode integration files are owned and
      # overwritten by `herdr integration install`, so nothing we add there
      # survives an upgrade.
      #
      # The three env guards are herdr's own contract (the integration hooks
      # test the same trio): outside a herdr pane the variables are unset and
      # this is a no-op, so it stays harmless in a plain terminal.
      #
      # chpwd fires on cd only, so the initial directory needs the explicit call
      # after it — that first push is the one that matters for an agent pane,
      # since the shell there usually launches the agent and never cds again.
      #
      # `&|` disowns: report-metadata is a unix-socket round trip on the order of
      # milliseconds, but a prompt has no business blocking on a socket that may
      # be gone (server restarted, session detached). Errors go to /dev/null for
      # the same reason — a dead socket must not print over the prompt.
      #
      # --source namespaces the metadata, so this can't collide with the agent
      # state the integration hooks report under `herdr:claude`.
      herdrCwdHook = ''
        if [[ -n ''${HERDR_ENV-} && -n ''${HERDR_PANE_ID-} && -n ''${HERDR_SOCKET_PATH-} ]]; then
          _herdr_report_cwd() {
            ${lib.getExe' herdr "herdr"} pane report-metadata "$HERDR_PANE_ID" \
              --source zsh-cwd --token "cwd=''${PWD/#$HOME/~}" >/dev/null 2>&1 &|
          }
          chpwd_functions+=(_herdr_report_cwd)
          _herdr_report_cwd
        fi
      '';
    in
    {
      # Ordered after the zsh module's own init (mkOrder 1000) purely so the
      # hook lands in a predictable place in .zshrc; it depends on nothing there.
      programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
        lib.mkOrder 1100 herdrCwdHook
      );

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
      # Actions these expose (`herdr plugin action list`): persiyanov.reviewr's
      # open/close/toggle, and pickr's route + toggle-auto. reviewr.toggle is
      # bound to prefix+d in herdrConfig above; the rest are unbound — pickr is
      # driven by Ctrl+clicking a link, and auto = false in pickrConfig already
      # means the chooser always shows, so toggle-auto has nothing to add.
      home.activation.herdrPluginLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-pickr} \
          || warnEcho "herdr: failed to link the herdr-pickr plugin"
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-reviewr} \
          || warnEcho "herdr: failed to link the herdr-reviewr plugin"
      '';

      # A writable copy rather than a symlink — see the header. `install -D`
      # creates the parent dir, and -m 0644 keeps it writable by herdr after the
      # store file's read-only mode. The reload is best-effort: it fails when no
      # server is running, which is the normal case during a fresh switch, so it
      # stays quiet rather than warning.
      home.activation.herdrConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run install -D -m 0644 ${herdrConfig} \
          ${config.xdg.configHome}/herdr/config.toml
        run ${lib.getExe' herdr "herdr"} server reload-config >/dev/null 2>&1 || true
      '';
    };
}
