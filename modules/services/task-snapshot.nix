# task-snapshot: CLI tool that outputs a snapshot of Obsidian tasks
# Replicates the scoring and views from TaskBases.base
{ ... }:
{
  flake.modules.homeManager.taskSnapshot =
    { config, pkgs, ... }:
    let
      tasksDir = "${config.secondBrain.basePath}/TasksBases/Tasks";

      python = pkgs.python3.withPackages (ps: [ ps.python-frontmatter ]);

      snapshotScript = pkgs.writeText "task_snapshot.py" ''
        #!/usr/bin/env python3
        """Obsidian task snapshot — mirrors TaskBases.base scoring and views."""

        import sys
        import os
        from datetime import date, timedelta
        from pathlib import Path
        from collections import Counter

        import frontmatter

        TASKS_DIR = Path("${tasksDir}")
        TODAY = date.today()


        # ── Colors ───────────────────────────────────────────────────────
        class C:
            """ANSI color codes, disabled when piped or --no-color."""
            BOLD = RESET = DIM = RED = GREEN = YELLOW = BLUE = CYAN = ""

        def init_colors(force_off=False):
            if not force_off and sys.stdout.isatty():
                C.BOLD, C.DIM, C.RESET = "\033[1m", "\033[2m", "\033[0m"
                C.RED, C.GREEN, C.YELLOW = "\033[31m", "\033[32m", "\033[33m"
                C.BLUE, C.CYAN = "\033[34m", "\033[36m"


        # ── Task model ───────────────────────────────────────────────────
        class Task:
            def __init__(self, path: Path):
                self.path = path
                post = frontmatter.load(path)
                meta = post.metadata
                self.name = path.stem
                self.completed = meta.get("completed", False)
                self.urgent = meta.get("urgent", False) is True
                self.important = meta.get("important", False) is True
                self.today = meta.get("today", False) is True
                self.area = meta.get("area", "") or ""
                self.spoons = meta.get("spoons", 0) or 0

                raw_due = meta.get("due")
                self.due = self._parse_date(raw_due)
                raw_es = meta.get("earliest_start")
                self.earliest_start = self._parse_date(raw_es)

                raw_ca = meta.get("completed_at")
                self.completed_at = self._parse_date(raw_ca)

            @staticmethod
            def _parse_date(val):
                if val is None:
                    return None
                if isinstance(val, date):
                    return val
                try:
                    return date.fromisoformat(str(val))
                except (ValueError, TypeError):
                    return None

            # ── Score formulas (matching TaskBases.base) ──
            @property
            def priority_weight(self):
                if self.urgent and self.important:
                    return 40
                if self.important:
                    return 30
                if self.urgent:
                    return 20
                return 10

            @property
            def urgency_score(self):
                if self.due is None:
                    return 0
                diff = (self.due - TODAY).days
                if diff < 0:
                    return 40
                if diff <= 3:
                    return 30
                if diff <= 7:
                    return 10
                return 0

            @property
            def today_bonus(self):
                return 20 if self.today else 0

            @property
            def score(self):
                return self.priority_weight + self.urgency_score + self.today_bonus

            @property
            def quadrant(self):
                if self.urgent and self.important:
                    return "Do First"
                if self.important:
                    return "Schedule"
                if self.urgent:
                    return "Batch"
                return "Defer"

            @property
            def quadrant_color(self):
                return {
                    "Do First": C.RED, "Schedule": C.BLUE,
                    "Batch": C.YELLOW, "Defer": C.DIM,
                }.get(self.quadrant, "")


        # ── Helpers ──────────────────────────────────────────────────────
        def section(title):
            print(f"\n{C.BOLD}== {title} =={C.RESET}")

        def or_none(items: list[str]):
            if items:
                print("\n".join(items))
            else:
                print(f"  {C.DIM}(none){C.RESET}")


        # ── Main ─────────────────────────────────────────────────────────
        def main():
            no_color = "--no-color" in sys.argv
            init_colors(force_off=no_color)

            all_tasks = []
            for p in sorted(TASKS_DIR.glob("*.md")):
                try:
                    all_tasks.append(Task(p))
                except Exception as e:
                    print(f"  {C.YELLOW}warning: skipping {p.name}: {e}{C.RESET}", file=sys.stderr)

            active = [t for t in all_tasks if not t.completed]
            completed_count = len(all_tasks) - len(active)

            # ── Summary ──
            section(f"Task Snapshot ({TODAY})")
            print(f"Total: {len(all_tasks)}  Active: {len(active)}  Completed: {completed_count}")

            # ── Eisenhower Quadrants ──
            section("Eisenhower Quadrants (active only)")
            qcounts = Counter(t.quadrant for t in active)
            print(f"  {C.RED}Do First{C.RESET} (urgent+important):     {qcounts.get('Do First', 0)}")
            print(f"  {C.BLUE}Schedule{C.RESET} (important, not urgent): {qcounts.get('Schedule', 0)}")
            print(f"  {C.YELLOW}Batch{C.RESET}    (urgent, not important):  {qcounts.get('Batch', 0)}")
            print(f"  {C.DIM}Defer{C.RESET}    (neither):                {qcounts.get('Defer', 0)}")

            # ── Active by Area ──
            section("Active Tasks by Area")
            acounts = Counter(t.area or "(inbox)" for t in active)
            or_none([f"  {count:4d}  {area}" for area, count in acounts.most_common()])

            # ── Today List (active today + completed today) ──
            section("Today List (sorted by score)")
            completed_today = [t for t in all_tasks if t.completed_at == TODAY]
            today_active = [t for t in active if t.today]
            today_all = sorted(
                {id(t): t for t in today_active + completed_today}.values(),
                key=lambda t: (t.completed, -t.score),
            )
            or_none([
                f"  {C.DIM}[done]{C.RESET} [{t.area}] {t.name}" if t.completed else
                f"  {C.GREEN}[{t.area}]{C.RESET} {t.name:<40s} {C.DIM}{t.spoons} spoons{C.RESET}  score:{t.score}"
                for t in today_all
            ])

            # ── Up Next ──
            section("Up Next (score >= 40, not today)")
            up_next = sorted([t for t in active if not t.today and t.score >= 40
                              and (not t.earliest_start or t.earliest_start <= TODAY + timedelta(days=1))],
                             key=lambda t: -t.score)
            or_none([
                f"  {C.CYAN}[{t.area}]{C.RESET} {t.name:<40s} {t.quadrant_color}{t.quadrant:<10s}{C.RESET} score:{t.score}"
                for t in up_next
            ])

            # ── Overdue ──
            section("Overdue (due date in the past)")
            overdue = sorted([t for t in active if t.due and t.due < TODAY], key=lambda t: t.due)
            or_none([f"  {C.RED}{t.due}{C.RESET}  {t.name}" for t in overdue])

            # ── Upcoming (due within 7 days) ──
            section("Upcoming (due within 7 days)")
            week = TODAY + timedelta(days=7)
            upcoming = sorted(
                [t for t in active if t.due and TODAY <= t.due <= week],
                key=lambda t: t.due,
            )
            or_none([f"  {C.YELLOW}{t.due}{C.RESET}  {t.name}" for t in upcoming])

            # ── Snoozed ──
            section("Snoozed (earliest_start in the future)")
            snoozed = sorted(
                [t for t in active if t.earliest_start and t.earliest_start > TODAY],
                key=lambda t: t.earliest_start,
            )
            or_none([f"  {C.CYAN}{t.earliest_start}{C.RESET}  {t.name}" for t in snoozed])

            # ── Inbox ──
            section("Inbox (untriaged)")
            inbox = [t for t in active if not t.area]
            or_none([f"  {t.name}" for t in inbox])

            # ── Area group views ──
            def area_view(title, areas):
                section(title)
                tasks = sorted(
                    [t for t in active if t.area in areas],
                    key=lambda t: (-t.score, t.area, t.name),
                )
                or_none([
                    f"  [{t.area:<10s}] {t.name:<40s} {t.quadrant:<10s} {t.spoons} spoons  score:{t.score}"
                    for t in tasks
                ])

            area_view("Business (covenant / quickjack / typestream / biz-dev)",
                       {"covenant", "quickjack", "typestream", "biz-dev"})
            area_view("Home Life (finances / taxes / health / family / home / rentals)",
                       {"finances", "taxes", "health", "family", "home", "rentals"})
            area_view("Fun", {"fun"})

            # ── Completed Today ──
            section("Completed Today")
            or_none([
                f"  {C.GREEN}[{t.area or '?'}]{C.RESET} {t.name}"
                for t in sorted(completed_today, key=lambda t: t.name)
            ])

            # ── Spoon Budget ──
            section("Spoon Budget (all active tasks)")
            total_spoons = sum(t.spoons for t in active if t.spoons)
            print(f"  Total spoons across all active tasks: {total_spoons:.1f}")
            print()


        if __name__ == "__main__":
            main()
      '';

      script = pkgs.writeShellScriptBin "task-snapshot" ''
        exec ${python}/bin/python3 ${snapshotScript} "$@"
      '';
    in
    {
      home.packages = [ script ];
    };
}
