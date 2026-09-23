#!/usr/bin/env python3
"""Push PDF attachments from notmuch into paperless-ngx with their email metadata.

Three subcommands:
  sync       ship new attachments from allowlisted senders (the nightly job),
             then run the context pass over everything
  unmatched  report senders with PDFs that no category covers, so the
             allowlist can be grown deliberately
  repair     the context pass on its own, for after a bulk reprocess wiped
             `content` on documents that already had their email attached

Uploads are fire-and-forget. `post_document` returns a task UUID, not a
document id, so the email body cannot be attached in the same breath as the
upload -- that is what the context pass is for, and why it is a phase of every
run rather than a repair tool. See MAIL-SYNC-SPEC.md in home-infrastructure-flux.

See modules/services/paperless-mail-sync.nix for why this uses the REST API
rather than the consume directory, and why incrementality keys off notmuch's
lastmod rather than dates or mtimes.
"""

from __future__ import annotations

import email
import email.policy
import json
import os
import subprocess
import sys
import time
from email.utils import parsedate_to_datetime
from pathlib import Path

import requests

CONTEXT_MARKER = "--- Email context ---"

# How many Message-IDs to put in one `in` query. Verified against the live
# instance: 400 ids (a 35KB URL) still answered 200, so 200 is well inside what
# both paperless and the ingress accept, at ~9 requests for a full 1,700-document
# reconciliation.
MSGID_BATCH = 200

CFG = json.loads(Path(os.environ["PAPERLESS_CONFIG"]).read_text())
STATE = Path(os.environ["PAPERLESS_STATE"])
URL = CFG["url"].rstrip("/")
TOKEN = Path(os.environ["PAPERLESS_TOKEN_FILE"]).read_text().strip()

S = requests.Session()
S.headers["Authorization"] = f"Token {TOKEN}"

# domain -> category, inverted from the category -> [domains] map in the nix file
DOMAIN_CATEGORY = {
    d: cat for cat, domains in CFG["categories"].items() for d in domains
}


def api(method: str, path: str, **kw):
    r = S.request(method, f"{URL}/api{path}", timeout=60, **kw)
    r.raise_for_status()
    return r.json() if r.content else None


def notmuch(*args: str) -> str:
    return subprocess.run(
        ["notmuch", *args], capture_output=True, text=True, check=True
    ).stdout


# ---------------------------------------------------------------- taxonomy ---
# Everything this creates is matching_algorithm 0 (None) on purpose. The importer
# already knows the correspondent from the From: header, so there is nothing to
# guess -- and a correspondent with a match rule would start auto-assigning
# itself to the ~5,500 documents that came from ~/Documents.
def ensure(kind: str, name: str, cache: dict) -> int:
    if name in cache:
        return cache[name]
    found = api("GET", f"/{kind}/", params={"name__iexact": name})
    if found["results"]:
        cache[name] = found["results"][0]["id"]
    else:
        cache[name] = api(
            "POST", f"/{kind}/", json={"name": name, "matching_algorithm": 0}
        )["id"]
    return cache[name]


def ensure_custom_field(name: str, cache: dict) -> int:
    if name in cache:
        return cache[name]
    found = api("GET", "/custom_fields/", params={"name__iexact": name})
    if found["results"]:
        cache[name] = found["results"][0]["id"]
    else:
        cache[name] = api(
            "POST", "/custom_fields/", json={"name": name, "data_type": "string"}
        )["id"]
    return cache[name]


# ------------------------------------------------------------------- state ---
def read_state() -> tuple[str | None, int]:
    f = STATE / "lastmod.json"
    if not f.exists():
        return None, 0
    d = json.loads(f.read_text())
    return d.get("uuid"), int(d.get("lastmod", 0))


def current_revision() -> tuple[str, int]:
    # `notmuch count --lastmod '*'` prints: <count>\t<uuid>\t<lastmod>
    parts = notmuch("count", "--lastmod", "*").strip().split("\t")
    return parts[1], int(parts[2])


def write_state(uuid: str, lastmod: int) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / "lastmod.json").write_text(
        json.dumps({"uuid": uuid, "lastmod": lastmod})
    )


# -------------------------------------------------------------------- mail ---
def domain_of(addr: str) -> str:
    return addr.rsplit("@", 1)[-1].strip(">").strip().lower() if "@" in addr else ""


def parse_message(path: str):
    with open(path, "rb") as fh:
        return email.message_from_binary_file(fh, policy=email.policy.default)


def body_text(msg) -> str:
    try:
        part = msg.get_body(preferencelist=("plain",))
        if part:
            return part.get_content().strip()
    except Exception:
        pass
    return ""


def pdf_attachments(msg):
    for part in msg.walk():
        fn = part.get_filename()
        if not fn or not fn.lower().endswith(".pdf"):
            continue
        try:
            payload = part.get_payload(decode=True)
        except Exception:
            continue
        if payload:
            yield fn, payload


def pdf_filenames(msg) -> list[str]:
    """Attachment names only. The pre-filter needs these before deciding whether
    any payload is worth decoding."""
    return [
        fn for fn in (part.get_filename() for part in msg.walk())
        if fn and fn.lower().endswith(".pdf")
    ]


def context_block(msg, msgid: str) -> str:
    """The block appended to a document's `content`.

    `content` specifically, not a note and not a custom field: it is the only one
    of the three that plain full-text search looks at without a field prefix, and
    the only one paperless's LLM/RAG path reads (it embeds document.content).
    A reprocess regenerates content from the file and drops this, which is why
    the context pass runs on every sync and is keyed on the Message-ID.
    """
    head = "\n".join(
        f"{k}: {msg.get(k, '')}" for k in ("From", "To", "Cc", "Date", "Subject")
        if msg.get(k)
    )
    return f"\n\n{CONTEXT_MARKER}\n{head}\nMessage-ID: {msgid}\n\n{body_text(msg)}\n"


# ----------------------------------------------------------- reconciliation ---
def chunks(items: list, size: int):
    for i in range(0, len(items), size):
        yield items[i : i + size]


def msgid_field_id() -> int | None:
    fld = api("GET", "/custom_fields/", params={"name__iexact": "Email Message-ID"})
    return fld["results"][0]["id"] if fld["results"] else None


def existing_attachments(msgids: list[str]) -> set[tuple[str, str]]:
    """Which (Message-ID, filename) pairs paperless already holds.

    Keyed on the PAIR, not on the Message-ID alone: one email with two
    attachments becomes two documents sharing a Message-ID (verified live), so a
    msgid-only filter would permanently skip the second attachment of any email
    whose first one landed and whose second one did not.

    This is a pre-filter, not the dedupe. Paperless rejects content duplicates by
    SHA-256 regardless -- but only AFTER the file has been uploaded, staged and
    queued, which is exactly the work worth not doing 1,200 times.
    """
    if not msgids:
        return set()
    fid = msgid_field_id()
    if fid is None:
        return set()

    seen: set[tuple[str, str]] = set()
    for batch in chunks(sorted(set(msgids)), MSGID_BATCH):
        page = "/documents/?page_size=100&custom_field_query=" + json.dumps(
            ["Email Message-ID", "in", batch]
        )
        while page:
            res = api("GET", page.replace(URL + "/api", ""))
            for doc in res["results"]:
                name = doc.get("original_file_name")
                for f in doc.get("custom_fields", []):
                    if f["field"] == fid and f.get("value") and name:
                        seen.add((f["value"], name))
            page = res.get("next")
    return seen


# -------------------------------------------------------------------- sync ---
def wait_for_paperless(timeout: int = 120) -> None:
    """Block until paperless answers, or give up.

    The counterpart to the automount-polling loop in paperless-sync.nix. systemd
    fires Persistent=true catch-up runs in the same second the laptop finishes
    resuming from suspend, well before Wi-Fi has associated -- that exact race
    cost laptop-backup.nix nine consecutive nights of backups. Without this the
    run just fails and waits 5 minutes for the RestartSec retry.
    """
    deadline = time.time() + timeout
    while True:
        try:
            S.get(f"{URL}/api/ui_settings/", timeout=10).raise_for_status()
            return
        except Exception as e:
            if time.time() >= deadline:
                raise SystemExit(f"paperless unreachable after {timeout}s: {e}")
            time.sleep(5)


def sync() -> int:
    wait_for_paperless()
    uuid_seen, last = read_state()
    uuid_now, rev_now = current_revision()

    if uuid_seen and uuid_seen != uuid_now:
        print(
            f"notmuch database UUID changed ({uuid_seen} -> {uuid_now}); "
            "revisions restarted, doing a full pass",
            file=sys.stderr,
        )
        last = 0

    domains = " or ".join(f"from:{d}" for d in DOMAIN_CATEGORY)
    query = f"attachment:pdf and ({domains})"
    if last:
        query += f" and lastmod:{last}.."
        print(f"Incremental: notmuch revision {last}..{rev_now}")
    else:
        print("First run: full backfill of the allowlisted senders")

    paths = [p for p in notmuch("search", "--output=files", query).splitlines() if p]
    print(f"{len(paths)} candidate message file(s)")

    failed = 0

    # -- phase 0: enumerate. Headers and attachment names only, no payloads and
    # nothing retained, so the reconciliation query below can be asked once for
    # the whole window instead of once per message.
    candidates: list[tuple[str, str, list[str]]] = []
    seen_msgids: set[str] = set()
    for path in paths:
        try:
            msg = parse_message(path)
        except Exception as e:
            print(f"  ! unreadable {path}: {e}", file=sys.stderr)
            failed += 1
            continue

        msgid = (msg.get("Message-ID") or "").strip("<> \t")
        # lieer stores one file per Gmail label, so the same message appears at
        # several paths. Message-ID collapses them.
        if msgid and msgid in seen_msgids:
            continue
        seen_msgids.add(msgid)

        if not DOMAIN_CATEGORY.get(domain_of(msg.get("From", ""))):
            continue
        names = pdf_filenames(msg)
        if names:
            candidates.append((path, msgid, names))

    already = existing_attachments([m for _, m, _ in candidates if m])
    print(f"{len(candidates)} message(s) from allowlisted senders; "
          f"paperless already holds {len(already)} of their attachment(s)")

    c_cache: dict = {}
    t_cache: dict = {}
    f_cache: dict = {}
    email_tag = ensure("tags", "Email", t_cache)
    fld_from = ensure_custom_field("Email From", f_cache)
    fld_msgid = ensure_custom_field("Email Message-ID", f_cache)

    submitted = skipped = 0

    # -- phase 1: upload, fire and forget. `post_document` answers with a task
    # UUID, not a document, so there is nothing here worth waiting for: waiting
    # is what serialised the whole run behind OCR. The email body is attached by
    # the context pass below, keyed on Message-ID.
    for path, msgid, names in candidates:
        wanted = [fn for fn in names if (msgid, fn) not in already]
        if not wanted:
            skipped += len(names)
            continue
        try:
            msg = parse_message(path)
        except Exception as e:
            print(f"  ! unreadable {path}: {e}", file=sys.stderr)
            failed += 1
            continue

        sender = msg.get("From", "")
        dom = domain_of(sender)
        category = DOMAIN_CATEGORY[dom]
        corr_name = CFG["correspondents"].get(dom, dom)
        corr = ensure("correspondents", corr_name, c_cache)
        cat_tag = ensure("tags", category, t_cache)

        try:
            created = parsedate_to_datetime(msg.get("Date")).isoformat()
        except Exception:
            created = None

        subject = (msg.get("Subject") or "(no subject)").strip()

        for fn, payload in pdf_attachments(msg):
            if fn not in wanted:
                skipped += 1
                continue
            data = {
                "title": subject[:120],
                "correspondent": str(corr),
                "tags": [str(email_tag), str(cat_tag)],
                "custom_fields": json.dumps({
                    str(fld_from): sender,
                    str(fld_msgid): msgid,
                }),
            }
            if created:
                data["created"] = created
            try:
                api(
                    "POST",
                    "/documents/post_document/",
                    files={"document": (fn, payload, "application/pdf")},
                    data=data,
                )
                submitted += 1
                print(f"  + [{category}] {corr_name}: {subject[:60]}")
            except Exception as e:
                print(f"  ! {fn}: {e}", file=sys.stderr)
                failed += 1

    # Advance the watermark ONLY on a clean pass. Per-message exceptions are
    # caught and counted above, so without this check a mid-run network drop
    # would fail every remaining message and still move the watermark past them
    # -- they would never be retried and would silently never reach paperless.
    #
    # "Clean" now means every upload was ACCEPTED, not that every document was
    # stored: nothing here can know the latter any more. That is safe, because
    # an upload that never becomes a document leaves its Message-ID absent from
    # the reconciliation query, so the next run re-sends it -- and if it did land,
    # SHA-256 dedupe makes the retry a single rejected POST rather than a copy.
    if failed:
        print(
            f"\n{failed} failure(s); leaving the watermark at {last} so the next "
            "run retries this window",
            file=sys.stderr,
        )
    else:
        write_state(uuid_now, rev_now)
    print(f"submitted={submitted} already-present={skipped} failed={failed}")

    # -- phase 2: attach the email context to whatever has landed, including
    # uploads from earlier runs that were still in the OCR queue last time.
    context_pass()
    return 1 if failed else 0


# --------------------------------------------------------------- unmatched ---
def unmatched() -> int:
    """Senders with PDF attachments that no category covers.

    Deliberately limited to the last year: a domain that has gone quiet is a
    finished relationship, not a gap in the allowlist.
    """
    known = set(DOMAIN_CATEGORY)
    counts: dict[str, int] = {}
    out = notmuch("address", "--output=count", "--output=address",
                  "attachment:pdf and date:1y..")
    for line in out.splitlines():
        if not line.strip():
            continue
        n, addr = line.split("\t", 1) if "\t" in line else line.split(None, 1)
        dom = domain_of(addr)
        if dom and dom not in known:
            counts[dom] = counts.get(dom, 0) + int(n)

    print("Senders with PDFs in the last year, not in any category:\n")
    for dom, n in sorted(counts.items(), key=lambda x: -x[1])[:40]:
        print(f"  {n:5}  {dom}")
    print("\nAdd the useful ones to modules/services/paperless-mail-sync.nix")
    return 0


# ------------------------------------------------------------ context pass ---
def context_pass() -> int:
    """Attach the email headers and body to every mail document missing them.

    Phase 2 of every sync, and the whole of `repair`. One query answers both
    jobs, because "the context was never attached yet" and "a reprocess
    regenerated `content` and dropped it" are the same question: which documents
    carry an Email Message-ID and no context block.

    Deliberately NOT scoped to the run's notmuch window. A document uploaded by
    this run is usually still in the OCR queue when this runs, so it is the next
    run that attaches its context -- and by then it is outside that run's window.
    The cost of staying unscoped is pagination, not PATCHes: documents that
    already have their context are skipped without touching the network.
    """
    fid = msgid_field_id()
    if fid is None:
        print("No 'Email Message-ID' field yet - nothing to attach.")
        return 0

    fixed = missing = 0
    page = "/documents/?page_size=100&custom_field_query=" + json.dumps(
        ["Email Message-ID", "exists", True]
    )
    while page:
        res = api("GET", page.replace(URL + "/api", ""))
        for doc in res["results"]:
            if CONTEXT_MARKER in (doc.get("content") or ""):
                continue
            msgid = next(
                (f["value"] for f in doc.get("custom_fields", [])
                 if f["field"] == fid), None,
            )
            if not msgid:
                continue
            paths = notmuch("search", "--output=files", f"id:{msgid}").splitlines()
            if not paths:
                print(f"  ? doc {doc['id']}: message {msgid} not in notmuch")
                missing += 1
                continue
            msg = parse_message(paths[0])
            api("PATCH", f"/documents/{doc['id']}/",
                json={"content": (doc.get("content") or "")
                      + context_block(msg, msgid)})
            fixed += 1
            print(f"  ~ attached context to doc {doc['id']}")
        page = res.get("next")
    print(f"context attached={fixed} unmatched-in-notmuch={missing}")
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sync"
    sys.exit({"sync": sync, "unmatched": unmatched, "repair": context_pass}[cmd]())
