# task-snapshot: CLI tool that outputs a snapshot of Obsidian tasks.
#
# The scorer lives in ./task_snapshot.py as plain Python, NOT inlined in a Nix
# string. It was embedded until 2026-09-26 and that cost real time: no syntax
# highlighting or linting applied to 700 lines of Python, a stray dollar-brace
# would silently break the Nix parse, and nothing could be run without a
# rebuild. Every edit had to go through a patch script with exact-match
# asserts.
#
# The only thing the Python needed from Nix was the tasks directory. The
# wrapper passes it as TASK_SNAPSHOT_DIR, so the file is directly runnable
# during development:
#
#     python3 modules/services/task_snapshot.py --no-color --spoons 4
#
# It needs python-frontmatter on the path; the wrapper supplies that too.
{ ... }:
{
  flake.modules.homeManager.taskSnapshot =
    { config, pkgs, ... }:
    let
      tasksDir = "${config.secondBrain.basePath}/TasksBases/Tasks";

      python = pkgs.python3.withPackages (ps: [ ps.python-frontmatter ]);

      script = pkgs.writeShellScriptBin "task-snapshot" ''
        export TASK_SNAPSHOT_DIR="${tasksDir}"
        exec ${python}/bin/python3 ${./task_snapshot.py} "$@"
      '';
    in
    {
      home.packages = [ script ];
    };
}
