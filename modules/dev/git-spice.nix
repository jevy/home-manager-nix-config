# git-spice — stacked branches/PRs on top of git (`gs` CLI, nixpkgs package).
# home-manager has no programs.git-spice module (checked); git-spice reads its
# config from git config (spice.* keys), so the package is all that's needed.
#
# Plus `gs-review`: open one branch of a stack in a review TUI. See below for
# why that needs its own command.
{
  flake.modules.homeManager.gitSpice =
    { pkgs, ... }:
    let
      # ── gs-review ────────────────────────────────────────────────────────────
      # On a stack, "review this branch" and "review main...HEAD" are wildly
      # different diffs — a branch four deep shows dozens of unrelated commits.
      # Every reviewer here guesses the base rather than being told it:
      #   reviewr  scans refs/remotes/origin for an ancestor (so an unpushed
      #            branch resolves to whatever IS pushed below it)
      #   hunk     takes a range but won't compute one
      #   tuicr    same — `-r <REVSET>`, no notion of a stack
      # git-spice already TRACKS the base (it's what `gs restack` rebases onto),
      # so read it from `gs ls --json` instead of re-deriving it. `.down.name` on
      # the `current: true` entry is the branch immediately below in the stack.
      #
      # NAME: not `gsr` — oh-my-zsh's git plugin ships `alias gsr='git svn
      # rebase'` (modules/shell/zsh.nix enables that plugin), and an alias
      # shadows a PATH binary in interactive zsh.
      #
      # tuicr/hunk are looked up on PATH rather than pinned via runtimeInputs, so
      # a host can import gitSpice without dragging both reviewers into its
      # closure. Missing tool → an explicit error, not a bare "command not found".
      gs-review = pkgs.writeShellApplication {
        name = "gs-review";
        runtimeInputs = [
          pkgs.git-spice
          pkgs.jq
          pkgs.git
        ];
        text = ''
          usage() {
            cat >&2 <<'EOF'
          gs-review [tuicr|hunk] [extra args…]

          Review ONLY the current branch's own changes — diffed against the base
          git-spice tracks for it, not against main.

            gs-review              # tuicr (comments; readable via `tuicr review comments`)
            gs-review -w           # …including uncommitted work
            gs-review hunk         # read-only quick look
            gs-review hunk --watch

          Extra args pass through to the tool. Falls back to origin/HEAD when the
          branch isn't tracked by git-spice.
          EOF
          }

          tool=tuicr
          case "''${1:-}" in
            tuicr | hunk)
              tool="$1"
              shift
              ;;
            -h | --help)
              usage
              exit 0
              ;;
          esac

          if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
            echo "gs-review: not inside a git repository" >&2
            exit 1
          fi

          # One JSON object per line; the current branch carries `current: true`.
          # `.down` is absent on trunk, so `// empty` collapses that to "".
          base="$(gs ls --json 2>/dev/null | jq -r 'select(.current == true) | .down.name // empty' || true)"

          if [ -z "$base" ]; then
            base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
            if [ -n "$base" ]; then
              echo "gs-review: no git-spice base for this branch — falling back to $base" >&2
            fi
          fi

          if [ -z "$base" ]; then
            echo "gs-review: could not resolve a base branch (not tracked by git-spice, and no origin/HEAD)" >&2
            echo "gs-review: track it with \`gs branch track\`, or pass a range to the tool directly" >&2
            exit 1
          fi

          if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
            echo "gs-review: base '$base' is not a commit-ish in this repo" >&2
            exit 1
          fi

          # `...` (merge-base), not `..`: if the base branch advances before you
          # restack onto it, `..` starts folding the base's new commits into
          # "your" diff. `...` stays anchored to where you actually branched.
          range="$base...HEAD"

          if [ "$(git rev-list --count "$base..HEAD")" -eq 0 ]; then
            echo "gs-review: no commits on this branch yet (base: $base)" >&2
            if [ "$tool" = tuicr ]; then
              echo "gs-review: pass -w to review uncommitted work" >&2
            fi
          fi

          if ! command -v "$tool" >/dev/null 2>&1; then
            echo "gs-review: $tool is not on PATH — is its home-manager module imported on this host?" >&2
            exit 1
          fi

          case "$tool" in
            tuicr) exec tuicr -r "$range" "$@" ;;
            hunk) exec hunk diff "$range" "$@" ;;
          esac
        '';
      };
    in
    {
      home.packages = [
        pkgs.git-spice
        gs-review
      ];
    };
}
