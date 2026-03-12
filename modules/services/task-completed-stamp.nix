# Watches the Tasks directory and stamps completed_at when a task is marked done.
# Guard: only stamps if the file's mtime is today (ignores stale inotify events on restart).
{ ... }:
{
  flake.modules.homeManager.taskCompletedStamp =
    { pkgs, ... }:
    let
      tasksDir = "/home/jevin/Second Brain Obsidian/Second Brain/TasksBases/Tasks";

      grep = "${pkgs.gnugrep}/bin/grep";
      sed = "${pkgs.gnused}/bin/sed";
      date = "${pkgs.coreutils}/bin/date";
      stat = "${pkgs.coreutils}/bin/stat";
      basename = "${pkgs.coreutils}/bin/basename";

      handler = pkgs.writeShellScript "stamp-completed-at" ''
        set -uo pipefail

        file="$1"

        # Only process .md files
        case "$file" in *.md) ;; *) exit 0 ;; esac

        # Must have completed: true
        ${grep} -q '^completed: true' "$file" 2>/dev/null || exit 0

        # Must NOT already have a completed_at date (blank is ok to overwrite)
        existing="$(${grep} '^completed_at:' "$file" 2>/dev/null | ${sed} 's/^completed_at: *//')"
        if [ -n "$existing" ]; then
          exit 0
        fi

        # Guard: file mtime must be today (skip stale events)
        file_date="$(${date} -d "@$(${stat} --format='%Y' "$file")" +%Y-%m-%d)"
        today="$(${date} +%Y-%m-%d)"
        if [ "$file_date" != "$today" ]; then
          exit 0
        fi

        # Stamp it
        ${sed} -i "s/^completed_at:.*$/completed_at: $today/" "$file"
        echo "Stamped completed_at: $today on $(${basename} "$file" .md)"
      '';

      watcher = pkgs.writeShellScript "watch-task-completions" ''
        set -uo pipefail

        TASKS="${tasksDir}"

        echo "Watching $TASKS for task completions..."

        ${pkgs.inotify-tools}/bin/inotifywait \
          --monitor \
          --event close_write \
          --format '%w%f' \
          "$TASKS" | while IFS= read -r file; do
            ${handler} "$file"
          done
      '';
    in
    {
      systemd.user.services.task-completed-stamp = {
        Unit = {
          Description = "Watch Obsidian tasks and stamp completed_at date";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = toString watcher;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
