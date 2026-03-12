{ ... }:
{
  flake.modules.homeManager.taskArchiver =
    { pkgs, ... }:
    let
      tasksDir = "/home/jevin/Second Brain Obsidian/Second Brain/TasksBases/Tasks";
      archiveDir = "/home/jevin/Second Brain Obsidian/Second Brain/TasksBases/Archive";

      script = pkgs.writeShellScript "archive-completed-tasks" ''
        set -euo pipefail

        TASKS_DIR="${tasksDir}"
        ARCHIVE_DIR="${archiveDir}"

        mkdir -p "$ARCHIVE_DIR"

        ${pkgs.findutils}/bin/find "$TASKS_DIR" -maxdepth 1 -name '*.md' -mtime +14 -print0 | \
          while IFS= read -r -d "" file; do
            if ${pkgs.gnugrep}/bin/grep -q '^category: Inbox' "$file"; then
              continue
            fi
            if ${pkgs.gnugrep}/bin/grep -q '^completed: true' "$file"; then
              mv "$file" "$ARCHIVE_DIR/"
              echo "Archived: $(basename "$file")"
            fi
          done
      '';
    in
    {
      systemd.user.services.task-archiver = {
        Unit.Description = "Archive completed Obsidian tasks older than 2 weeks";
        Service = {
          Type = "oneshot";
          ExecStart = toString script;
        };
      };

      systemd.user.timers.task-archiver = {
        Unit.Description = "Daily archive of completed Obsidian tasks";
        Timer = {
          OnCalendar = "daily";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
