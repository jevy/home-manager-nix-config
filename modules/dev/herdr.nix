# herdr — terminal workspace manager for AI coding agents (panes, tabs, agents,
# worktrees), plus two plugins that split the review work between them:
#   pickr      — Ctrl+click an *open* PR/MR link → pick a reviewer (tuicr posts
#                comments back to the forge).
#   herdr-hunk — fzf picker → any local diff in a hunk pane. Plus hunk-send
#                (ours, defined below), which pushes the notes you typed in hunk
#                into the agent's input.
#
# Not in nixpkgs, and upstream's flake ships packages only (no home-manager
# module), so the package comes straight off the flake input.
#
# ── Why hunk, not reviewr ────────────────────────────────────────────────────
# This slot used to hold persiyanov.reviewr. Both review an agent's local diff
# beside the chat; the split that decided it:
#
#   * SCOPES. reviewr has three (u/b/t) and cannot separate staged from
#     unstaged — its `uncommitted` scope is staged + unstaged + untracked in one
#     view. herdr-hunk's picker has seven, staged among them, and every row
#     re-points an ALREADY LIVE session (`hunk session reload`) instead of
#     opening a second pane. One key opens the review and re-scopes it.
#
#   * INLINE ROUND-TRIP. reviewr has no write API, so a comment can only travel
#     one way: you → agent, arriving as an ordinary chat message. hunk exposes
#     `hunk session comment add --focus`, so an agent can put a note ON line 42
#     and move the cursor to it, and `navigate --next-comment` walks you
#     through them. That is a conversation about the diff rather than a message
#     about the diff, and it is the reason for the switch.
#
# WHAT WAS GIVEN UP: reviewr's `last turn` scope — the diff of just what an
# agent changed in its most recent turn. hunk has no notion of agent turns, so
# there is no equivalent and no way to build one short of tracking turn-start
# refs ourselves. herdr-hunk's autodiff fires on the same event (an agent going
# idle) but shows the working tree, not that turn's slice. In practice the
# working-tree view plus `git diff` covers it; if it turns out not to, reviewr
# is a revert of this commit away.
#
# WHAT WAS REBUILT: reviewr's `s` (send comments to the agent). hunk's note
# flow is pull-based — notes sit in the session until something runs
# `hunk session comment list` — so the push half is `hunk-send` below, bound to
# prefix+shift+s.
#
# ── Hotkeys ──────────────────────────────────────────────────────────────────
# Upstream defaults except where `herdrConfig` below overrides them (currently
# only prefix+j/k). `herdr --default-config` prints the authoritative default
# list; `prefix+?` shows the live bindings in-app.
#
# Prefix is ctrl+b. "prefix+x" means ctrl+b then x — not a simultaneous chord.
#
# EVERYTHING WE CHANGED, in full — five bindings, plus prefix+b listed only
# because it is the one people assume we took. Nothing else differs from stock:
#
#   key             | ours                | upstream default there
#   ----------------+---------------------+--------------------------------
#   prefix+j        | next_workspace      | focus_pane_down    (now unbound)
#   prefix+k        | previous_workspace  | focus_pane_up      (now unbound)
#   prefix+tab      | last_pane           | cycle_pane_next    (now unbound)
#   prefix+d        | hunk picker         | (free upstream)
#   prefix+shift+s  | hunk-send           | (free upstream)
#   prefix+b        | UNCHANGED           | toggle_sidebar
#
# So only THREE upstream bindings were displaced: focus_pane_down/up and
# cycle_pane_next. prefix+d and prefix+shift+s took free keys. Rest is stock.
#
# prefix+b is NOT ours: it toggles herdr's OWN sidebar (the workspace/tab
# tree), and has nothing to do with reviewing. The review pane is prefix+d.
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
#   Panes — i.e. moving between the agent and a review pane (hunk, tuicr)
#     prefix+d          hunk picker  ← ours. Opens the review, and re-scopes an
#                       already-open one. See the plugin action below. It lands
#                       in the tab you pressed the key in, and pulls a hunk pane
#                       autodiff left in another tab over to yours rather than
#                       reloading it out of sight — patches 5-6 in
#                       pkgs/herdr-hunk.nix, neither of which upstream does.
#     prefix+shift+s    send your hunk notes to the agent  ← ours (hunk-send)
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
#   in that tab — which is exactly what a hunk split gives you. To move between
#   agents, use the tab keys above, not the pane keys.
#
#   Inside the review tools themselves
#     pickr chooser     t tuicr · h hunk · d plain diff · o browser · q cancel
#     hunk picker (fzf) Working tree (live) · Staged · Last commit · Pick commit
#                       · Pick range (TAB marks two) · Branch vs upstream ·
#                       Stash. Esc cancels.
#     hunk              c write a note, then CTRL+S to save it (Esc cancels) —
#                       Enter inserts a newline, it does NOT save · q quit.
#                       Opened with --watch, so it follows the agent's edits.
#                       Notes reach the agent only when you press prefix+shift+s.
#     tuicr             c line comment · C file comment · <leader>c review
#                       comment · m/M next/prev comment · :e reload the diff
#                       (tuicr does NOT auto-reload) · q quit
#
#   THE LOCAL REVIEW LOOP, end to end:
#     prefix+d          open hunk on the working tree (or pick another scope)
#     c … ctrl+s        write a note on a line, repeat
#     prefix+shift+s    push every note into the agent's input, focus it
#     <type, Enter>     add a sentence if you like, then send
#   The notes are REMOVED from the pane once sent — that is the signal they
#   went. See hunk-send below.
#
# ── Plugins ──────────────────────────────────────────────────────────────────
# herdr has no declarative plugin option: `herdr plugin install owner/repo`
# git-clones into ~/.config/herdr/plugins/github and registers the checkout in
# ~/.config/herdr/plugins.json, which herdr rewrites at runtime (enable/disable).
# That registry can't be a read-only home.file symlink, so plugins land the other
# way round: Nix stages each plugin directory into the store (pkgs/herdr-pickr.nix,
# pkgs/herdr-hunk.nix) and activation calls `herdr plugin link <store-path>`,
# which registers a local path without cloning or running build hooks. `link`
# replaces any existing entry for the same plugin id, so re-running it every
# activation is idempotent and repoints the registry at the new store path after
# an input bump — including over an entry left by an imperative
# `herdr plugin install`, since both resolve to the same manifest `id`.
#
# The asymmetry to remember: `link` can add and replace, but nothing here can
# REMOVE. A plugin dropped from the activation script stays in plugins.json
# pointing at a garbage-collected store path until `herdr plugin unlink <id>`
# is run by hand.
#
# A plugin's own config IS declarative where the plugin has one: herdr only
# creates ~/.config/herdr/plugins/config/<id>/ and never reads or writes what's
# inside, so pickr's config.toml is a plain home.file symlink. herdr-hunk is the
# exception — its one setting is a marker FILE that its own toggle action
# creates and deletes, so it has to stay imperative. See the xdg.configFile
# block below.
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
      # nixpkgs, not the `herdr` flake input. Both are 0.7.5 and Apache-2.0,
      # but they are byte-different derivations and only the nixpkgs one is in
      # cache.nixos.org — its narinfo returns 200 where the flake input's
      # returns 404. Using the input therefore compiled herdr, and a whole Rust
      # toolchain, from source on any machine with a cold store. Found while
      # building the devbox closure (home-infrastructure-flux apps/devbox) on a
      # clean CI runner — the only place a cold store is ever visible here.
      #
      # Trade-off: herdr version bumps now wait on nixpkgs instead of tracking
      # upstream directly. The `herdr` input is still declared in flake.nix, so
      # switching back is a one-line revert if you need a release nixpkgs has
      # not picked up yet.
      herdr = pkgs.herdr;
      herdr-pickr = pkgs.callPackage ../../pkgs/herdr-pickr.nix { src = inputs.herdr-pickr; };
      herdr-hunk = pkgs.callPackage ../../pkgs/herdr-hunk.nix { src = inputs.herdr-hunk; };

      # ── hunk-send ────────────────────────────────────────────────────────────
      # The one thing hunk has no answer for. hunk's note flow is pull-based:
      # you press `c`, write a note, `ctrl+s`, and it sits in the session until
      # an agent thinks to run `hunk session comment list`. reviewr's `s` was
      # push — it typed the comments straight into the agent's input — and that
      # is the half worth keeping. Neither herdr-hunk nor any other hunk plugin
      # does this; it is ours.
      #
      # Bound to prefix+shift+S below, deliberately echoing reviewr's `s`.
      #
      # Verified session semantics (probed against a live pane, not inferred):
      #   * notes typed in the TUI come back as source = "user", noteId
      #     "user:<ts>-<n>", editable = true;
      #   * notes added over the CLI are source = "agent", noteId "mcp:<uuid>",
      #     editable = false — EVEN with --author set. So `--type user` is an
      #     exact filter for "what the human typed", and an agent can annotate
      #     the same session without its own notes echoing back at it.
      #
      # Sent notes are removed. That mirrors reviewr (send clears) and keeps the
      # pane honest about what is still outstanding — but it is a real deletion:
      # the text lives only in the agent's input box afterwards, so it is gone
      # if you clear the box without submitting.
      #
      # Text is inserted WITHOUT a newline. `herdr pane run` would send text and
      # Enter together; send-text lets you add a sentence before submitting,
      # which is usually the point of asking a question about a diff.
      hunk-send = pkgs.writeShellApplication {
        name = "hunk-send";
        runtimeInputs = [
          pkgs.jq
          pkgs.git
        ];
        text = ''
          # herdr passes its own path to plugin commands, but this runs as a
          # plain keybinding, so fall back to PATH.
          H="''${HERDR_BIN_PATH:-herdr}"

          die() {
            echo "hunk-send: $1" >&2
            "$H" notification show "hunk-send: $1" --position top-right >/dev/null 2>&1 || true
            exit 1
          }

          cur="$("$H" pane current 2>/dev/null)" || die "not inside herdr"
          ws="$(printf '%s' "$cur" | jq -r '.result.pane.workspace_id // empty')"
          cwd="$(printf '%s' "$cur" | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty')"
          [ -n "$ws" ] || die "could not read the focused pane"

          # Which repo's notes? The focused pane's, when that pane is in a repo
          # with a live session — the common case, since you press this either
          # from the hunk pane or from the agent beside it.
          #
          # Falling back to a scan of the workspace is not defensive padding: a
          # hunk pane can be reviewing a DIFFERENT directory than the agent
          # (`--cwd` at open time, a worktree, a scratch checkout), and then the
          # focused pane resolves to a repo with no session while the notes sit
          # in one right beside it. Resolving strictly from the focused pane
          # fails there with a confusing "no live hunk session for <the wrong
          # repo>".
          root=""
          if [ -n "$cwd" ]; then
            cand="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
            if [ -n "$cand" ] && hunk session get --repo "$cand" >/dev/null 2>&1; then
              root="$cand"
            fi
          fi

          if [ -z "$root" ]; then
            # Every repo with a live session, intersected with the repos this
            # workspace's panes are sitting in — so a session in an unrelated
            # workspace is never picked up.
            live="$(hunk session list --json 2>/dev/null |
              jq -r '.sessions[]?.repoRoot // empty' | sort -u)"
            for p in $("$H" pane list --workspace "$ws" 2>/dev/null |
              jq -r '.result.panes[]?.cwd // empty'); do
              cand="$(git -C "$p" rev-parse --show-toplevel 2>/dev/null || true)"
              [ -n "$cand" ] || continue
              if printf '%s\n' "$live" | grep -qxF "$cand"; then
                root="$cand"
                break
              fi
            done
          fi

          [ -n "$root" ] ||
            die "no live hunk session in this workspace (open one with prefix+d)"

          notes="$(hunk session comment list --repo "$root" --type user --json 2>/dev/null)" ||
            die "could not read notes"

          count="$(printf '%s' "$notes" | jq -r '.comments | length')"
          [ "$count" -gt 0 ] || die "no notes to send"

          # file:line — body. A range prints as start-end; a note on a removed
          # line carries oldRange instead of newRange.
          body="$(printf '%s' "$notes" | jq -r '
            def loc:
              (.newRange // .oldRange) as $r
              | if $r == null then ""
                elif $r[0] == $r[1] then ":\($r[0])"
                else ":\($r[0])-\($r[1])"
                end;
            "Review notes from hunk (\(.comments | length)):\n\n"
            + ([.comments[] | "- \(.filePath)\(loc) — \(.body)"] | join("\n"))
            + "\n"')"

          # herdr agent list only reports panes running an agent, so the hunk
          # pane can never be the target. More than one agent in a workspace is
          # unusual here (an agent gets a tab, a workspace holds one task), so
          # the first is the right one; a second would need a picker.
          target="$("$H" agent list 2>/dev/null |
            jq -r --arg ws "$ws" '
              [.result.agents[]? | select(.workspace_id == $ws) | .pane_id] | first // empty')"
          [ -n "$target" ] || die "no agent pane in this workspace"

          "$H" pane send-text "$target" "$body" >/dev/null ||
            die "could not send to $target"

          # Only after a successful send. Each id individually: a note the user
          # added between the list and here must not be swept up with them.
          printf '%s' "$notes" | jq -r '.comments[].noteId' | while IFS= read -r id; do
            [ -n "$id" ] || continue
            hunk session comment rm --repo "$root" "$id" >/dev/null 2>&1 || true
          done

          "$H" pane focus "$target" >/dev/null 2>&1 || true
          "$H" notification show "sent $count note(s) to the agent" \
            --position top-right >/dev/null 2>&1 || true
        '';
      };

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
          # prefix+d ("diff") opens herdr-hunk's picker — the entry point for
          # every local review, since pickr's rows all interpolate a forge {url}
          # and so need a PR to exist. Free in upstream's map: only
          # prefix+shift+d (close workspace) is taken.
          #
          # The picker, not the plain `open-hunk-watch` toggle: each of its rows
          # reloads an already-live hunk session rather than stacking a second
          # pane, so one key both opens the review and re-scopes it. That is
          # what replaces reviewr's u/b/t.
          #
          # prefix+shift+s sends your notes back (see hunk-send above) — `s`
          # for send, matching the key reviewr used for the same motion. It is a
          # plain `shell` command, not a plugin action: nothing in the plugin
          # knows about hunk's note API.
          command = [
            {
              key = "prefix+d";
              type = "plugin_action";
              command = "herdr-hunk.open-hunk-picker";
            }
            {
              key = "prefix+shift+s";
              type = "shell";
              command = "${lib.getExe hunk-send}";
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
      # modules, which every host importing this one also imports. hunk-send is
      # a package rather than an inline command so it can also be run by hand
      # (and read with `type hunk-send`) when the keybinding misbehaves.
      home.packages = [
        herdr
        hunk-send
      ];

      # ~/.config/herdr/plugins/config/<id>/ — the id maps to the directory
      # name verbatim.
      #
      # herdr-hunk gets no config file: it has none. Its only setting is the
      # presence of an `autodiff-off` marker file in this directory, which
      # `toggle-autodiff` creates and deletes — so it must stay imperative.
      # Declaring it here would make it a read-only store symlink and break the
      # toggle, the same trap that forces herdr's own config.toml to be
      # installed as a writable copy (see the header).
      #
      # That leaves autodiff ON by default: when an agent goes idle with
      # uncommitted changes, a hunk pane opens beside it, unfocused. It
      # de-duplicates on a hash of the diff, so a pane you close by hand stays
      # closed until the content actually changes.
      xdg.configFile."herdr/plugins/config/pickr/config.toml".text = pickrConfig;

      # Registers (or re-points) each plugin. Works with no herdr server running:
      # the CLI falls back to writing plugins.json directly. Non-fatal — when a
      # herdr server from a previous version is still running, `link` is routed
      # through its socket and can fail on a protocol mismatch, which shouldn't
      # take the whole switch down; restarting herdr and re-running fixes it.
      #
      # Actions these expose (`herdr plugin action list`): herdr-hunk's
      # open-hunk-picker / open-hunk-picker-tab / open-hunk-watch /
      # toggle-autodiff, and pickr's route + toggle-auto. Only
      # open-hunk-picker is bound (prefix+d, above); the rest are reachable
      # through `herdr plugin action invoke` if ever wanted.
      #
      # NOTE: this only ADDS links. `herdr plugin link` replaces an entry with
      # the same id, but it cannot remove one — a plugin dropped from this list
      # stays registered in ~/.config/herdr/plugins.json until it is unlinked by
      # hand. Dropping reviewr therefore needed a one-off
      # `herdr plugin unlink persiyanov.reviewr`.
      home.activation.herdrPluginLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-pickr} \
          || warnEcho "herdr: failed to link the herdr-pickr plugin"
        run ${lib.getExe' herdr "herdr"} plugin link ${herdr-hunk} \
          || warnEcho "herdr: failed to link the herdr-hunk plugin"
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
