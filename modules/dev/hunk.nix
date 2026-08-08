# Hunk — review-first terminal diff viewer for agent-authored changesets
# (github:modem-dev/hunk). Not in nixpkgs — vimPlugins.hunk-nvim is an
# unrelated julienvincent plugin — so consumed via upstream's flake, which
# ships its own home-manager module.
#
# This is the DEFAULT local reviewer here; tuicr is the forge one. See the
# header of modules/dev/herdr.nix for the keybindings and the plugin wiring.
#
# The Claude Code skill is upstream's own file (it ships inside the hunk
# package) with a local section appended — see pkgs/claude-skill-hunk. A plain
# store symlink is safe because Claude Code only ever READS a skill directory,
# and home.file symlinks the exact path, leaving the other imperatively-managed
# skills in ~/.claude/skills alone.
{ inputs, ... }:
{
  flake.modules.homeManager.hunk =
    { pkgs, ... }:
    {
      imports = [ inputs.hunk.homeManagerModules.default ];
      programs.hunk = {
        enable = true;
        # Sets hunk as the default git pager; requires programs.git.enable
        # (provided by the git module on every host that imports this).
        enableGitIntegration = true;
      };

      home.file.".claude/skills/hunk-review".source = pkgs.callPackage ../../pkgs/claude-skill-hunk {
        hunk = inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
    };
}
