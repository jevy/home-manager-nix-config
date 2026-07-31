# direnv + nix-direnv — per-directory environments (.envrc / devenv auto-load).
#
# IMPORTANT: `programs.direnv.enable` is what installs the zsh shell hook — the
# precmd/chpwd `eval "$(direnv hook zsh)"` that fires on every prompt and cd.
# Just having the direnv *package* on PATH is NOT enough: without the hook,
# entering a directory never triggers a reload and .envrc only loads when you
# run `direnv` by hand. (This is the trap the Mac fell into — desktop-mac.nix
# shipped the bare package but not the hook.)
{ ... }:
{
  flake.modules.homeManager.direnv =
    { ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true; # faster nix/devenv caching
      };
    };
}
