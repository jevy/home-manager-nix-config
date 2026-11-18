# `clip FILE` plus the `clipboard-copy` Claude Code skill that drives it.
#
# Text Claude prints in the terminal is not pasteable: the renderer adds quote
# bars and indentation and hard-wraps long lines. The skill has Claude write
# pasteable text to /tmp/clip/<slug>.{txt,md,html} instead and run `clip` on
# it, so it lands on the clipboard formatted for the destination (plain for
# input boxes like YouTube, Slack markdown, or rich text for Gmail).
#
# Cross-platform on purpose, unlike modules/desktop/clipboard.nix (Hyprland):
# `clip` uses wl-copy on Linux and pbcopy + textutil on macOS, so the skill
# says one thing on both hosts.
#
# The skill directory is a store symlink, same as modules/dev/hunk.nix: Claude
# Code only reads it, and home.file links this one path, leaving the
# imperatively-managed skills in ~/.claude/skills alone.
{ ... }:
{
  flake.modules.homeManager.clipboardCopy =
    { pkgs, lib, ... }:
    let
      clip = pkgs.writeShellApplication {
        name = "clip";
        runtimeInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wl-clipboard ];
        text = builtins.readFile ../../pkgs/clip/clip.sh;
      };
    in
    {
      home.packages = [ clip ];
      home.file.".claude/skills/clipboard-copy".source = ../../pkgs/claude-skill-clipboard-copy;
    };
}
