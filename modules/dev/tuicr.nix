# tuicr — terminal PR review TUI (comments go back to the forge). Not in
# nixpkgs, so it comes from upstream's flake (naersk-built Rust, all four
# unix systems). Useful standalone (`tuicr pr <url>`) and doubles as the
# default reviewer backend for herdr-pickr — see modules/dev/herdr.nix.
#
# This module also installs the Claude Code skill that teaches agents tuicr's
# `review` CLI. It lives here rather than in claude-code.nix because it is built
# from `inputs.tuicr` and must stay pinned to the binary it drives. Safe to
# couple: every host importing tuicr also imports herdr and claudeCode.
#
# Unlike herdr's config.toml (a writable copy — see modules/dev/herdr.nix),
# this is a plain store symlink. Claude Code only ever READS a skill directory,
# so there is no in-place write to break. home.file symlinks the exact path,
# leaving the other, imperatively-managed skills in ~/.claude/skills alone.
{ inputs, ... }:
{
  flake.modules.homeManager.tuicr =
    { pkgs, ... }:
    let
      claude-skill-tuicr = pkgs.callPackage ../../pkgs/claude-skill-tuicr { src = inputs.tuicr; };
    in
    {
      home.packages = [ inputs.tuicr.packages.${pkgs.stdenv.hostPlatform.system}.default ];

      home.file.".claude/skills/tuicr".source = claude-skill-tuicr;
    };
}
