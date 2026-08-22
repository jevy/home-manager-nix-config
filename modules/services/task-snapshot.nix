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
        import json
        from datetime import date, timedelta
        from pathlib import Path
        from collections import Counter

        import frontmatter

        TASKS_DIR = Path("${tasksDir}")
        TODAY = date.today()


        # ── Colors ───────────────────────────────────────────────────────
        class C:
            """ANSI color codes, disabled when piped or --no-color."""
            BOLD = RESET = DIM = RED = GREEN = YELLOW = BLUE = CYAN = REV = ""

        def init_colors(force_off=False):
            if not force_off and sys.stdout.isatty():
                C.BOLD, C.DIM, C.RESET = "\033[1m", "\033[2m", "\033[0m"
                C.RED, C.GREEN, C.YELLOW = "\033[31m", "\033[32m", "\033[33m"
                C.BLUE, C.CYAN = "\033[34m", "\033[36m"
                C.REV = "\033[7m"


        # ── Task model ───────────────────────────────────────────────────
        class Task:
            def __init__(self, path: Path):
                self.path = path
                post = frontmatter.load(path)
                meta = post.metadata
                self.name = path.stem
                self.completed = meta.get("completed", False)
                self.archived = meta.get("archived", False) is True
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

                # ── Waiting: what someone else owes me ──
                # completed and waiting coexist on purpose. "completed" answers
                # "did I do my part?"; "status: waiting" answers "is the concern
                # resolved?" For ball-passing work those differ.
                self.status = (meta.get("status", "") or "").strip().lower()
                self.waiting_on = meta.get("waiting_on", "") or ""
                self.waiting_for = meta.get("waiting_for", "") or ""
                self.waiting_since = self._parse_date(meta.get("waiting_since"))
                self.last_nudged = self._parse_date(meta.get("last_nudged"))
                self.nudge_after = meta.get("nudge_after", 7) or 7
                self.escalation = meta.get("escalation", "") or ""

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

            # ── Waiting properties ──
            @property
            def is_waiting(self):
                return self.status == "waiting"

            @property
            def silence_start(self):
                """Clock start: a nudge resets it, otherwise when the wait began."""
                return self.last_nudged or self.waiting_since

            @property
            def days_silent(self):
                if self.silence_start is None:
                    return None
                return (TODAY - self.silence_start).days

            @property
            def is_stale(self):
                """An undated wait always nags — that is the correct behaviour."""
                if self.days_silent is None:
                    return True
                return self.days_silent >= self.nudge_after

            @property
            def total_days_waiting(self):
                if self.waiting_since is None:
                    return None
                return (TODAY - self.waiting_since).days


        # ── Helpers ──────────────────────────────────────────────────────
        def section(title):
            print(f"\n{C.BOLD}== {title} =={C.RESET}")

        def or_none(items: list[str]):
            if items:
                print("\n".join(items))
            else:
                print(f"  {C.DIM}(none){C.RESET}")


        # ── Waiting ──────────────────────────────────────────────────────
        def sort_waiting(items):
            """Stale first, then longest-silent first. Undated sorts to the top."""
            return sorted(
                items,
                key=lambda t: (
                    not t.is_stale,
                    -(t.days_silent if t.days_silent is not None else 10**6),
                ),
            )


        def waiting_lines(waiting):
            """Render the Waiting On section, one or two lines per item."""
            out = []
            for t in waiting:
                if t.days_silent is None:
                    age, colour = "  ?", C.RED
                else:
                    age = f"{t.days_silent}d"
                    colour = C.RED if t.is_stale else C.DIM
                mark = f"{C.RED}⚠{C.RESET}" if t.is_stale else " "
                who = t.waiting_on or t.name
                what = t.waiting_for or t.name
                if t.days_silent is None:
                    note = f"{C.DIM}(start date unknown){C.RESET}"
                else:
                    note = f"{C.DIM}(nudge after {t.nudge_after}d){C.RESET}"
                out.append(
                    f"  {mark} {colour}{age:>4s}{C.RESET}  {C.CYAN}{who:<26.26s}{C.RESET} {what:<40.40s} {note}"
                )
                if t.is_stale and t.escalation:
                    out.append(f"       {C.YELLOW}→ escalate: {t.escalation}{C.RESET}")
            return out


        def build_json(all_tasks, active, waiting):
            """Machine-readable snapshot — the contract for any future digest."""
            def iso(d):
                return d.isoformat() if d else None

            overdue = [t for t in active if t.due and t.due < TODAY]
            today_active = [t for t in active if t.today]
            return {
                "generated_at": TODAY.isoformat(),
                "digest": {
                    "active": len(active),
                    "overdue": len(overdue),
                    "today_spoons": round(sum(t.spoons for t in today_active if t.spoons), 1),
                    "waiting": len(waiting),
                    "stale_waiting": sum(1 for t in waiting if t.is_stale),
                },
                "tasks": [
                    {
                        "name": t.name,
                        "area": t.area,
                        "score": t.score,
                        "spoons": t.spoons,
                        "quadrant": t.quadrant,
                        "due": iso(t.due),
                        "today": t.today,
                    }
                    for t in sorted(active, key=lambda t: -t.score)
                ],
                "waiting": [
                    {
                        "name": t.name,
                        "area": t.area,
                        "waiting_on": t.waiting_on,
                        "waiting_for": t.waiting_for,
                        "waiting_since": iso(t.waiting_since),
                        "last_nudged": iso(t.last_nudged),
                        "days_silent": t.days_silent,
                        "nudge_after": t.nudge_after,
                        "stale": t.is_stale,
                        "total_days_waiting": t.total_days_waiting,
                        "escalation": t.escalation,
                    }
                    for t in waiting
                ],
            }


        # ── Main ─────────────────────────────────────────────────────────
        def main():
            as_json = "--json" in sys.argv
            no_color = "--no-color" in sys.argv or as_json
            init_colors(force_off=no_color)

            all_tasks = []
            for p in sorted(TASKS_DIR.glob("*.md")):
                try:
                    all_tasks.append(Task(p))
                except Exception as e:
                    print(f"  {C.YELLOW}warning: skipping {p.name}: {e}{C.RESET}", file=sys.stderr)

            active = [t for t in all_tasks if not t.completed and not t.archived]
            archived = [t for t in all_tasks if t.archived and not t.completed]
            completed_count = sum(1 for t in all_tasks if t.completed)

            # Built from all_tasks, not active: a waiting item is usually
            # completed (I did my part) but the concern is still open.
            waiting = sort_waiting([t for t in all_tasks if t.is_waiting and not t.archived])

            if as_json:
                print(json.dumps(build_json(all_tasks, active, waiting), indent=2))
                return

            # ── Summary ──
            section(f"Task Snapshot ({TODAY})")
            print(f"Total: {len(all_tasks)}  Active: {len(active)}  Completed: {completed_count}  Archived: {len(archived)}")

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

            completed_today = [t for t in all_tasks if t.completed_at == TODAY]
            today_active = [t for t in active if t.today]

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

            # ── Waiting On ──
            section("Waiting On (what other people owe me)")
            or_none(waiting_lines(waiting))

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

            # ── Archived ──
            section("Archived")
            or_none([f"  {C.DIM}[{t.area or '?'}]{C.RESET} {t.name}" for t in sorted(archived, key=lambda t: t.name)])

            # ── Spoon Budget ──
            section("Spoon Budget (all active tasks)")
            total_spoons = sum(t.spoons for t in active if t.spoons)
            print(f"  Total spoons across all active tasks: {total_spoons:.1f}")

            # ── TODAY — last on purpose: this is what stays on screen ──
            today_view(today_active, completed_today, waiting)


        def today_view(today_active, completed_today, waiting=()):
            """The one section meant to be read, so it prints last."""
            rule = "─" * 66
            print(f"\n{C.BOLD}{rule}")
            print(f"  TODAY · {TODAY:%a %b %-d}")
            print(f"{rule}{C.RESET}")

            todo = sorted(today_active, key=lambda t: -t.score)
            if not todo:
                print(f"  {C.DIM}nothing flagged for today{C.RESET}")
            for t in todo:
                do_now = t.quadrant == "Do First" or (t.due and t.due <= TODAY)
                bullet = f"{C.RED}{C.BOLD}▶{C.RESET}" if do_now else " "
                name = t.name if len(t.name) <= 38 else t.name[:37] + "…"
                pad = " " * (38 - len(name))
                name = f"{C.BOLD}{name}{C.RESET}" if do_now else name
                quad = f"{t.quadrant_color}{C.REV} {t.quadrant:<8s} {C.RESET}"
                due = ""
                if t.due and t.due < TODAY:
                    due = f"  {C.RED}OVERDUE {t.due}{C.RESET}"
                elif t.due == TODAY:
                    due = f"  {C.RED}due today{C.RESET}"
                print(f"  {bullet} {quad} {name}{pad} {C.DIM}[{t.area or '?'}] {t.spoons} sp{C.RESET}{due}")

            spoons = sum(t.spoons for t in todo if t.spoons)
            done = len(completed_today)
            print(f"\n  {C.CYAN}{len(todo)} to do{C.RESET} · {spoons:.1f} spoons"
                  f" · {C.GREEN}{done} done today{C.RESET}")

            stale = sum(1 for t in waiting if t.is_stale)
            if stale:
                noun = "item needs" if stale == 1 else "items need"
                print(f"  {C.RED}⏳ {stale} waiting {noun} a nudge{C.RESET}")

            print(f"  {C.DIM}▶ = do it now (urgent+important or due){C.RESET}\n")


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
