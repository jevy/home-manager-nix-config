# task-snapshot: CLI that scores and ranks the Obsidian task notes.
#
# The scorer used to live here as ./task_snapshot.py. It moved to
# github.com/jevy/task-snapshot (PRIVATE) on 2026-09-26, because THIS repo
# is public and the area weights carry personal content that has no
# business being published. This repo's history was rewritten the same day
# to remove it. The extraction also gives the Hermes MCP sidecar an image
# to build from, but the privacy problem is why it happened when it did.
#
# The input is private, so `nix flake` operations here need SSH access to
# that repo. Nothing else evaluates this flake, which makes that an
# acceptable price for not publishing the kids' medical context.
#
# The only thing the package needs from Nix is the tasks directory, passed
# as TASK_SNAPSHOT_DIR. Develop against a checkout instead of rebuilding:
#
#     cd ~/code/personal/task-snapshot && nix develop
#     python -m task_snapshot --no-color --spoons 4
#
# This module also installs the interactive `todo-organizer` Claude Code skill,
# straight out of the input's source tree. That skill was a loose file in
# ~/.claude/skills until 2026-09-26, in no repo at all, and it had drifted: it
# still pointed at `AREA_COEFF in task-snapshot.nix` months after the constants
# moved into the package, and its frontmatter block was missing the six
# `waiting_*` fields the scorer reads. It now lives next to the numbers it
# describes, so prose and code change in one commit.
{ inputs, ... }:
{
  flake.modules.homeManager.taskSnapshot =
    { config, pkgs, ... }:
    let
      tasksDir = "${config.secondBrain.basePath}/TasksBases/Tasks";

      task-snapshot = inputs.task-snapshot.packages.${pkgs.stdenv.hostPlatform.system}.default;

      script = pkgs.writeShellScriptBin "task-snapshot" ''
        export TASK_SNAPSHOT_DIR="${tasksDir}"
        exec ${task-snapshot}/bin/task-snapshot "$@"
      '';
    in
    {
      home.packages = [ script ];

      # The skill, as a read-only store symlink. That is the point, not a side
      # effect: the previous copy was writable, so every session that "improved"
      # it drifted from the scorer silently. Editing now means editing the source
      # repo and `nix flake update task-snapshot`, which is exactly the friction
      # that keeps the two in step.
      #
      # Safe because Claude Code only READS a skill directory, and home.file
      # symlinks this one path, leaving the other imperatively-managed skills in
      # ~/.claude/skills alone. Same pattern as modules/dev/hunk.nix.
      #
      # The fragments inside it are inlined by the source repo's
      # scripts/sync-skills.sh, checked by its tests/test_skills_parity.py, and
      # that test suite runs in this derivation's checkPhase -- so a stale inline
      # cannot reach here without failing the build first.
      home.file.".claude/skills/todo-organizer".source =
        "${inputs.task-snapshot}/skills/todo-organizer";
    };
}
