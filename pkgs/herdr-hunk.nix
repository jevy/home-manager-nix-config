# herdr-hunk — a herdr plugin: an fzf picker that opens any diff in a hunk
# pane (working tree, staged, last commit, any commit, a two-commit range,
# branch vs upstream, a stash), plus an auto-open hook when an agent goes idle
# with uncommitted changes.
#
# Upstream is a plain script directory — `herdr-plugin.toml` plus five bash
# scripts under `scripts/` — with NO `[[build]]` hook at all, so this
# derivation only stages it into the store for `herdr plugin link`. That makes
# it the simplest of the three plugins here: pickr needs a shebang pinned,
# reviewr needs a whole Rust build.
#
# ── Why the picker matters ───────────────────────────────────────────────────
# Every entry routes through picker.sh's `view()`, which reloads an ALREADY
# LIVE hunk session (`hunk session reload`) instead of stacking a second pane.
# So the picker doubles as a scope switcher for an open review — the thing that
# replaces reviewr's u/b/t keys, over a wider set of scopes.
#
# ── Patches ──────────────────────────────────────────────────────────────────
# Six, all of them portability or correctness fixes upstream would want. 1–4
# are one-liners; 5–6 are the "open it in the tab I am looking at" pair, which
# gets its own section below.
#
#   1. PATH. herdr runs plugin ACTIONS and EVENTS with a minimal PATH (the same
#      constraint pkgs/herdr-reviewr.nix worked around), and upstream
#      compensates with a Homebrew/`/usr/local` prefix that finds nothing on
#      NixOS or nix-darwin. The store paths for the tools the scripts actually
#      call are baked in at the top of each script instead. Appending `$PATH`
#      keeps the user's profile visible, so `hunk` and `herdr` still resolve
#      the way upstream intends — see the note below on why those two are NOT
#      baked.
#
#   2. `..` → `...` in the picker's "Branch vs upstream" row. With `..`, any
#      commit the base picked up since you branched folds into "your" diff. The
#      symmetric form stays anchored at the merge-base. Same reasoning as the
#      `range=` line in modules/dev/git-spice.nix.
#
#   3. The "not found" hint says `brew install hunk`, which is wrong advice on
#      every host here.
#
#   4. `--preview-window=hidden` on the top-level fzf menu, so a `--preview` in
#      the inherited FZF_DEFAULT_OPTS can't render errors beside the rows.
#
# ── Patches 5–6: the review opens in the tab you are looking at ──────────────
# Two unrelated reasons `prefix+d` could put the diff in a DIFFERENT TAB of the
# same workspace:
#
#   5. NOTHING PINS THE SPLIT. `herdr plugin pane open` resolves an absent
#      --target-pane at OPEN time, from whatever is focused then — and a plugin
#      action runs detached, so that is later than the keypress. herdr already
#      hands the action the pane the key was pressed in (HERDR_PANE_ID), so
#      this is one flag. autodiff.sh already did it with the event's pane id.
#
#   6. A HUNK SESSION IS KEYED BY REPO ROOT, NOT BY TAB. picker.sh reloads a
#      live session rather than stacking a second viewer — the behaviour that
#      makes the picker a scope switcher, worth keeping — but that session's
#      pane may be in another tab, because autodiff opens one beside ANY agent
#      that goes idle with changes. Picking a scope then reloads a pane you
#      cannot see while the picker pane exits, so the review looks like it
#      opened somewhere else. Fix: move that pane here first, which keeps ONE
#      session per repo — what `hunk-send` (modules/dev/herdr.nix) resolves
#      against. It is found by label and cwd rather than by pid (which would
#      mean a `pane process-info` call per candidate): panes of this plugin all
#      carry the title "hunk", and a session is per repo anyway, so a hunk pane
#      sitting in the same repo in another tab is the one. Worst case it moves
#      a hunk pane that was not the session's — visible, and harmless.
#
# ── What is deliberately NOT baked ───────────────────────────────────────────
# `hunk` and `herdr` resolve from PATH. herdr passes its own path in
# HERDR_BIN_PATH, and hunk is a user-profile concern: which hunk you get should
# follow modules/dev/hunk.nix, not a second copy pinned here. Both are checked
# for explicitly by the scripts, so a missing one is a clear message rather
# than a bare "command not found".
{
  lib,
  stdenvNoCC,
  src,
  bash,
  jq,
  git,
  coreutils,
  fzf,
  perl,
  gawk,
  gnused,
  gnugrep,
}:
let
  # `shasum` is perl's, not coreutils' — autodiff.sh uses it to fingerprint the
  # working tree so a diff pane you closed by hand stays closed until the
  # content actually changes.
  runtimePath = lib.makeBinPath [
    jq
    git
    coreutils
    fzf
    perl
    gawk
    gnused
    gnugrep
  ];

  # Prepended to every script, immediately after its `set -uo pipefail`.
  pathLine = ''
    set -uo pipefail
    export PATH="${runtimePath}:''${PATH:-}"'';

  # Patch 5. Pins the pane the picker's split hangs off (and, for the `tab`
  # placement, the workspace the tab lands in) to the one the key was pressed
  # in. `extra` is already expanded into the `plugin pane open` argv below it,
  # so the flags ride along there. The case guards keep a malformed id — most
  # of all one starting with `-` — from being read as a flag.
  pickerPinPane = ''
    extra=()
    [ "$placement" = "split" ] && extra=(--direction right)

    # Pin the target: herdr resolves an absent --target-pane at open time,
    # which is after the keypress this action was spawned from. See the
    # "Patches 5-6" note in pkgs/herdr-hunk.nix.
    if [ "$placement" = "split" ]; then
      case "''${HERDR_PANE_ID:-}" in
        "" | -* | *[!A-Za-z0-9_:.-]*) ;;
        *) extra+=(--target-pane "$HERDR_PANE_ID") ;;
      esac
    else
      case "''${HERDR_WORKSPACE_ID:-}" in
        "" | -* | *[!A-Za-z0-9_:.-]*) ;;
        *) extra+=(--workspace "$HERDR_WORKSPACE_ID") ;;
      esac
    fi'';

  # Patch 6. `session_here` replaces the bare `hunk session get` test in both
  # of picker.sh's reuse paths: same answer (is there a live session for this
  # repo?), but a hunk pane sitting in another tab is dragged here first, so
  # the reload that follows happens where you can see it. Only the answer to
  # "is there a session" is load-bearing — every "cannot tell" (outside herdr,
  # no jq, no stray pane found) still reloads, exactly as upstream does.
  pickerSessionHere = ''
    herdr_bin="''${HERDR_BIN_PATH:-herdr}"

    session_here() {
      hunk session get --repo "$repo_root" >/dev/null 2>&1 || return 1
      [ -n "''${HERDR_PANE_ID:-}" ] && [ -n "''${HERDR_TAB_ID:-}" ] || return 0
      command -v jq >/dev/null 2>&1 || return 0

      # A hunk pane on this repo, elsewhere in THIS workspace — empty if one is
      # already in this tab (nothing to do) or if the only ones are in another
      # workspace (not ours to move). See the "Patches 5-6" note in
      # pkgs/herdr-hunk.nix.
      local stray
      stray="$("$herdr_bin" pane list 2>/dev/null |
        jq -r --arg w "''${HERDR_TAB_ID%%:*}" --arg t "$HERDR_TAB_ID" --arg r "$repo_root" '
          [.result.panes[]?
           | select(.label == "hunk" and .workspace_id == $w
                    and ((.foreground_cwd // .cwd // "") | startswith($r)))] as $hunks
          | if ($hunks | any(.tab_id == $t)) then ""
            else ($hunks | first | .pane_id // "") end')"
      case "$stray" in "" | -* | *[!A-Za-z0-9_:.-]*) return 0 ;; esac

      # --focus to match the fresh-open path, where the picker pane becomes the
      # viewer and keeps focus. This pane exits as soon as the reload lands.
      "$herdr_bin" pane move "$stray" --tab "$HERDR_TAB_ID" --split right \
        --target-pane "$HERDR_PANE_ID" --focus >/dev/null 2>&1 || true
    }

    # Session-aware: if a hunk viewer is already open for this repo, reload it
    # with the chosen view instead of opening a second one; else become hunk.
    view() {'';
in
stdenvNoCC.mkDerivation {
  pname = "herdr-hunk";
  # Upstream ships no tags; tracks `version` in herdr-plugin.toml.
  version = "0.1.1";
  inherit src;

  nativeBuildInputs = [ bash ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r herdr-plugin.toml scripts $out/
    chmod +x $out/scripts/*.sh

    # 1. PATH, in every script. --replace-fail on a line all five share, so an
    # upstream rewrite fails the build rather than silently shipping a plugin
    # that finds no jq.
    for s in autodiff.sh open-hunk-picker.sh open-hunk-watch.sh picker.sh toggle-autodiff.sh; do
      substituteInPlace $out/scripts/$s \
        --replace-fail 'set -uo pipefail' ${lib.escapeShellArg pathLine}
    done

    # …and neutralise upstream's own PATH line in autodiff.sh, which would
    # otherwise re-prepend Homebrew ahead of the store paths set above.
    substituteInPlace $out/scripts/autodiff.sh \
      --replace-fail \
        'export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"' \
        '# PATH is set at the top of this script by the Nix build.'

    # 2. Symmetric difference for the branch-vs-upstream row.
    substituteInPlace $out/scripts/picker.sh \
      --replace-fail 'view diff "$upstream..$branch"' 'view diff "$upstream...$branch"'

    # 3. Platform-correct hint.
    substituteInPlace $out/scripts/picker.sh \
      --replace-fail \
        "printf 'hunk not found on PATH (brew install hunk)\n'" \
        "printf 'hunk not found on PATH (is homeManager.hunk imported on this host?)\n'"

    # 4. Don't inherit a preview on the TOP-LEVEL menu. fzf applies
    # FZF_DEFAULT_OPTS to every invocation that doesn't override it, and the
    # menu's items are labels, not paths — so any `--preview '<pager> {}'` in a
    # user's environment renders
    #   [bat error]: 'Working tree (live)': No such file or directory
    # beside the list. The commit and stash pickers pass their own --preview and
    # are unaffected; this is the one call that inherits.
    #
    # modules/shell/zsh.nix no longer sets a global preview, which fixes the
    # cause — but this stays, because the env a plugin pane sees is NOT the one
    # that file produces. herdr spawns the picker as a non-interactive bash that
    # never sources zshrc, so it inherits the *herdr server's* environment,
    # captured whenever the server last started. A stale server therefore keeps
    # serving stale opts across rebuilds until it restarts, and any third-party
    # tool could reintroduce the same setting anyway.
    substituteInPlace $out/scripts/picker.sh \
      --replace-fail \
        "fzf --prompt='hunk> ' --reverse --height=100%" \
        "fzf --prompt='hunk> ' --reverse --height=100% --preview-window=hidden"

    # 5. Pin the picker pane to the pane the key was pressed in.
    substituteInPlace $out/scripts/open-hunk-picker.sh \
      --replace-fail \
        'extra=()
    [ "$placement" = "split" ] && extra=(--direction right)' \
        ${lib.escapeShellArg pickerPinPane}

    # 6. Reuse a live session only after bringing its pane into this tab. The
    # anchor is the `session get` test, which appears in BOTH reuse paths
    # (view() and the working-tree branch) — substituteInPlace rewrites both.
    substituteInPlace $out/scripts/picker.sh \
      --replace-fail \
        'hunk session get --repo "$repo_root" >/dev/null 2>&1 &&' \
        'session_here &&' \
      --replace-fail \
        '# Session-aware: if a hunk viewer is already open for this repo, reload it
    # with the chosen view instead of opening a second one; else become hunk.
    view() {' \
        ${lib.escapeShellArg pickerSessionHere}

    runHook postInstall
  '';

  # `#!/usr/bin/env bash` throughout. fixupPhase only patches $out/bin, so the
  # scripts/ directory needs it spelled out.
  postFixup = ''
    patchShebangs $out/scripts
  '';

  meta = {
    description = "herdr plugin: fzf picker opening any diff (working tree, staged, commit, range, stash) in a hunk pane";
    homepage = "https://github.com/JacquesvanWyk/herdr-hunk";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
