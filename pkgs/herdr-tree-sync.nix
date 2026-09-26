# herdr-tree-sync — keeps the `tree` sidebar token honest and current.
#
# The token itself (and why it exists) is documented in modules/dev/herdr.nix;
# this is the half that keeps it TRUE. The zsh chpwd hook there can only report
# where the *shell* stands, and that is the wrong answer twice over:
#
#   * An agent cds on its own. Claude Code working in
#     <repo>/.claude/worktrees/<name> leaves the pane's login shell parked in
#     the top-level checkout forever — chpwd never fires, so the hook reports
#     the checkout while the agent edits a worktree.
#   * chpwd cannot fire for a directory that is not a repo, and the old hook
#     skipped the workspace write when git said nothing, so a space whose
#     directory is not a repo kept whatever the first cwd reported — in
#     practice another space's worktree, rendered indefinitely.
#
# herdr already computes the true answer: `pane list` returns foreground_cwd,
# the cwd of the pane's foreground process group, read live from /proc at query
# time. This walks that, derives the same tree label the hook derives, and
# writes back only what changed (a metadata write repaints the sidebar, so an
# unconditional write every pass would flicker it).
#
# The token is the conflict signal: two spaces whose rows read the same repo or
# the same "(wt) <name>" are two agents in one tree.
{
  writeShellApplication,
  herdr,
  jq,
  git,
  coreutils,
}:
writeShellApplication {
  name = "herdr-tree-sync";
  runtimeInputs = [
    herdr
    jq
    git
    coreutils
  ];
  # A single pass by default, so it can be run by hand to see what it would
  # report; `--watch [seconds]` is the form the service uses.
  text = ''
    # Same source namespace the zsh hook writes `cwd` under: one writer per
    # token key, so `tree` here can never end up shadowed by a stale value
    # under a second source name.
    readonly SOURCE=zsh-cwd

    # The worktree test, identical to the hook's: --git-dir and --git-common-dir
    # agree in a top-level checkout and disagree inside a linked worktree. No
    # worktree list to parse, no assumption about where worktrees are kept.
    # Outside a repo the answer is the directory itself, never empty — an empty
    # answer is what stranded the old token.
    tree_for() (
      cd "$1" 2>/dev/null || return 0
      mapfile -t r < <(git rev-parse --git-dir --git-common-dir --show-toplevel 2>/dev/null)
      if (( ''${#r[@]} >= 3 )); then
        if [[ $(realpath -m "''${r[0]}") == $(realpath -m "''${r[1]}") ]]; then
          printf '%s' "''${r[2]/#$HOME/\~}"
        else
          printf '(wt) %s' "''${r[2]##*/}"
        fi
      else
        printf '%s' "''${PWD/#$HOME/\~}"
      fi
    )

    sync_once() {
      local panes spaces pane ws dir have agent tree
      # No server, or a server mid-restart: nothing to do, and never an error.
      panes=$(herdr pane list 2>/dev/null) || return 0
      spaces=$(herdr workspace list 2>/dev/null) || return 0
      [[ -n $panes && -n $spaces ]] || return 0

      local -A want_ws=() have_ws=() ws_from_agent=()

      while IFS=$'\t' read -r pane ws dir have agent; do
        [[ -n $pane ]] || continue
        tree=$(tree_for "$dir")
        [[ $tree == "$have" ]] || herdr pane report-metadata "$pane" \
          --source "$SOURCE" --token "tree=$tree" >/dev/null 2>&1
        # One token per space, and a space can hold several panes. An agent
        # pane wins: it is the one whose tree a conflict scan cares about.
        # Otherwise first pane listed, so the answer is at least stable.
        if [[ -z ''${want_ws[$ws]-} || ( -n $agent && -z ''${ws_from_agent[$ws]-} ) ]]; then
          want_ws[$ws]=$tree
          [[ -n $agent ]] && ws_from_agent[$ws]=1
        fi
      done < <(jq -r '.result.panes[]
        | [.pane_id, .workspace_id, (.foreground_cwd // .cwd // ""), (.tokens.tree // ""), (.agent // "")]
        | @tsv' <<<"$panes")

      while IFS=$'\t' read -r ws have; do
        [[ -n $ws ]] || continue
        have_ws[$ws]=$have
      done < <(jq -r '.result.workspaces[]
        | [.workspace_id, (.tokens.tree // "")]
        | @tsv' <<<"$spaces")

      for ws in "''${!want_ws[@]}"; do
        [[ ''${want_ws[$ws]} == "''${have_ws[$ws]-}" ]] && continue
        herdr workspace report-metadata "$ws" \
          --source "$SOURCE" --token "tree=''${want_ws[$ws]}" >/dev/null 2>&1
      done
    }

    if [[ ''${1-} == --watch ]]; then
      interval=''${2-5}
      while :; do
        sync_once
        sleep "$interval"
      done
    else
      sync_once
    fi
  '';

  meta = {
    description = "Keep herdr's `tree` sidebar token in step with each pane's real foreground directory";
    mainProgram = "herdr-tree-sync";
  };
}
