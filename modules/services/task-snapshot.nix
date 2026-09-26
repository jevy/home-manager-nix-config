# task-snapshot: CLI that scores and ranks the Obsidian task notes.
#
# The scorer used to live here as ./task_snapshot.py. It moved to
# github.com/jevy/task-snapshot (PRIVATE) on 2026-09-26, because THIS repo
# is public and the area weights carry comments naming three children,
# their redacted, a redacted and an open redacted. The extraction also
# gives the Hermes MCP sidecar an image to build from, but the privacy
# problem is why it happened when it did.
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
    };
}
