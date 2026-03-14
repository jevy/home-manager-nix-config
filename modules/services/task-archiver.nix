{ ... }:
{
  flake.modules.homeManager.taskArchiver =
    { config, pkgs, ... }:
    let
      tasksDir = "${config.secondBrain.basePath}/TasksBases/Tasks";
      archiveDir = "${config.secondBrain.basePath}/TasksBases/Archive";

      grep = "${pkgs.gnugrep}/bin/grep";
      sed = "${pkgs.gnused}/bin/sed";
      date = "${pkgs.coreutils}/bin/date";

      script = pkgs.writeShellScript "archive-completed-tasks" ''
        set -euo pipefail

        TASKS_DIR="${tasksDir}"
        ARCHIVE_DIR="${archiveDir}"
        CUTOFF=$(${date} -d '14 days ago' +%Y-%m-%d)

        mkdir -p "$ARCHIVE_DIR"

        for file in "$TASKS_DIR"/*.md; do
          [ -f "$file" ] || continue

          # Skip Inbox tasks
          ${grep} -q '^category: Inbox' "$file" && continue

          # Must be completed
          ${grep} -q '^completed: true' "$file" || continue

          # Parse completed_at date from frontmatter
          completed_at=$(${grep} '^completed_at:' "$file" | ${sed} 's/^completed_at: *//' | head -1)
          [ -z "$completed_at" ] && continue

          # Archive if completed_at is older than 14 days
          if [[ "$completed_at" < "$CUTOFF" || "$completed_at" == "$CUTOFF" ]]; then
            mv "$file" "$ARCHIVE_DIR/"
            echo "Archived: $(basename "$file") (completed_at: $completed_at)"
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
