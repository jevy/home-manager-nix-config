#!/usr/bin/env python3
"""Unit tests for paperless-mail-sync.

Run with:  python3 -m unittest discover -s modules/services -p 'test_*.py'

The module reads its config, state dir and token from the environment at import
time (it is a systemd-wrapped script, not a library), so those are faked here
before the import. Every HTTP call goes through `api()`, which is the single
seam these tests replace.
"""

from __future__ import annotations

import collections
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

_TMP = tempfile.mkdtemp(prefix="pms-test-")
Path(_TMP, "config.json").write_text(json.dumps({
    "url": "https://paperless.example/",
    "correspondents": {"example.com": "Example"},
    "categories": {"Finance": ["example.com"]},
}))
Path(_TMP, "token").write_text("test-token\n")
os.environ["PAPERLESS_CONFIG"] = str(Path(_TMP, "config.json"))
os.environ["PAPERLESS_STATE"] = str(Path(_TMP, "state"))
os.environ["PAPERLESS_TOKEN_FILE"] = str(Path(_TMP, "token"))

_spec = importlib.util.spec_from_file_location(
    "pms", Path(__file__).with_name("paperless-mail-sync.py")
)
pms = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pms)


class FakeApi:
    """Records every call and answers from a queue of canned responses."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    def __call__(self, method, path, **kw):
        self.calls.append((method, path, kw))
        return self.responses.pop(0) if self.responses else {"results": [], "next": None}


def doc(doc_id, msgid, filename, field_id=2, content=""):
    return {
        "id": doc_id,
        "content": content,
        "original_file_name": filename,
        "custom_fields": [{"field": field_id, "value": msgid}],
    }


class ChunksTest(unittest.TestCase):
    def test_splits_into_batches_of_the_given_size(self):
        self.assertEqual(
            list(pms.chunks([1, 2, 3, 4, 5], 2)), [[1, 2], [3, 4], [5]]
        )

    def test_empty_input_yields_nothing(self):
        self.assertEqual(list(pms.chunks([], 3)), [])


class ExistingAttachmentsTest(unittest.TestCase):
    def setUp(self):
        self._real_api = pms.api

    def tearDown(self):
        pms.api = self._real_api

    def test_returns_msgid_filename_pairs(self):
        pms.api = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [doc(10, "a@x", "one.pdf"), doc(11, "a@x", "two.pdf")],
             "next": None},
        ])
        self.assertEqual(
            pms.existing_attachments(["a@x"]),
            {"a@x": collections.Counter({"one.pdf": 1, "two.pdf": 1})},
        )

    def test_batches_the_in_query(self):
        fake = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [], "next": None},
            {"results": [], "next": None},
        ])
        pms.api = fake
        pms.existing_attachments([f"id{i}@x" for i in range(pms.MSGID_BATCH + 1)])
        queries = [
            json.loads(path.split("custom_field_query=", 1)[1])
            for _, path, _ in fake.calls
            if "custom_field_query=" in path
        ]
        self.assertEqual(len(queries), 2)
        self.assertEqual(queries[0][1], "in")
        self.assertEqual(len(queries[0][2]), pms.MSGID_BATCH)
        self.assertEqual(len(queries[1][2]), 1)

    def test_no_msgids_means_no_http_call(self):
        fake = FakeApi([])
        pms.api = fake
        self.assertEqual(pms.existing_attachments([]), {})
        self.assertEqual(fake.calls, [])

    def test_missing_custom_field_is_not_an_error(self):
        fake = FakeApi([{"results": []}])
        pms.api = fake
        self.assertEqual(pms.existing_attachments(["a@x"]), {})


class ContextPassTest(unittest.TestCase):
    def setUp(self):
        self._real_api = pms.api
        self._real_notmuch = pms.notmuch

    def tearDown(self):
        pms.api = self._real_api
        pms.notmuch = self._real_notmuch

    def test_pass_asks_for_every_document_with_a_msgid(self):
        # Deliberately unscoped: a document uploaded by THIS run is usually
        # still in the OCR queue when the pass runs, so it is the NEXT run that
        # attaches its context -- and by then it is outside that run's notmuch
        # window. Scoping the query to the window would strand it forever.
        fake = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [], "next": None},
        ])
        pms.api = fake
        pms.context_pass()
        q = json.loads(fake.calls[1][1].split("custom_field_query=", 1)[1])
        self.assertEqual(q, ["Email Message-ID", "exists", True])

    def test_documents_that_already_have_context_are_not_patched(self):
        fake = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [doc(10, "a@x", "one.pdf", content=pms.CONTEXT_MARKER)],
             "next": None},
        ])
        pms.api = fake
        pms.notmuch = lambda *a: self.fail("notmuch must not be consulted")
        pms.context_pass()
        self.assertEqual([c[0] for c in fake.calls], ["GET", "GET"])


# --------------------------------------------------------------------------
# Findings from the whole-branch review. Each test below reproduces one.
# --------------------------------------------------------------------------

MAIL = """From: Someone <bill@example.com>
Subject: Invoice
Date: Mon, 1 Jan 2024 10:00:00 +0000
Message-ID: <{msgid}>
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="b"

--b
Content-Type: text/plain

hello
--b
Content-Type: application/pdf
Content-Disposition: attachment; filename="{name1}"
Content-Transfer-Encoding: base64

JVBERi0xLjQK
--b
Content-Type: application/pdf
Content-Disposition: attachment; filename="{name2}"
Content-Transfer-Encoding: base64

JVBERi0xLjUK
--b--
"""


def mail(msgid="abc@example.com", name1="one.pdf", name2="two.pdf"):
    import email
    import email.policy
    return email.message_from_string(
        MAIL.format(msgid=msgid, name1=name1, name2=name2),
        policy=email.policy.default,
    )


class RoutingApi:
    """Answers by route instead of by queue, so sync() can be driven end to end."""

    def __init__(self, documents=None, post_raises=False):
        self.calls = []
        self.posts = []
        self.patches = []
        self.documents = documents or []
        self.post_raises = post_raises

    def __call__(self, method, path, **kw):
        self.calls.append((method, path, kw))
        if method == "POST" and "post_document" in path:
            if self.post_raises:
                raise RuntimeError("upload refused")
            self.posts.append(kw)
            return "task-uuid"
        if method == "PATCH":
            self.patches.append((path, kw))
            return {}
        if path.startswith("/documents/"):
            return {"results": self.documents, "next": None}
        if path.startswith("/custom_fields/"):
            return {"results": [{"id": 2, "name": "Email Message-ID"}]}
        return {"results": [{"id": 1}]}


class SyncHarness(unittest.TestCase):
    """Drives sync() with notmuch, the clock and the filesystem stubbed out."""

    def setUp(self):
        self.written = []
        self.api = RoutingApi()
        self._saved = {
            k: getattr(pms, k)
            for k in ("api", "notmuch", "parse_message", "wait_for_paperless",
                      "read_state", "current_revision", "write_state")
        }
        pms.api = self.api
        pms.wait_for_paperless = lambda *a, **k: None
        pms.read_state = lambda: (None, 0)
        pms.current_revision = lambda: ("uuid-1", 42)
        pms.write_state = lambda u, r: self.written.append((u, r))
        pms.notmuch = lambda *a: "/fake/mail\n"
        pms.parse_message = lambda path: mail()

    def tearDown(self):
        for k, v in self._saved.items():
            setattr(pms, k, v)


class DuplicateFilenameTest(SyncHarness):
    def test_second_attachment_sharing_a_filename_is_still_uploaded(self):
        # Both attachments are called scan.pdf and only ONE of them landed last
        # run. A set-valued pre-filter collapses them and skips the survivor
        # forever; the count has to survive.
        pms.parse_message = lambda path: mail(name1="scan.pdf", name2="scan.pdf")
        self.api.documents = [doc(10, "abc@example.com", "scan.pdf")]
        pms.sync()
        self.assertEqual(len(self.api.posts), 1)


class EmptyMessageIdTest(SyncHarness):
    def test_a_message_without_a_message_id_is_not_uploaded(self):
        # It could never be reconciled or given context, so uploading it means
        # re-uploading it on every run until the end of time.
        pms.parse_message = lambda path: mail(msgid="")
        pms.sync()
        self.assertEqual(self.api.posts, [])


class WatermarkTest(SyncHarness):
    def test_an_unreadable_file_does_not_freeze_the_watermark(self):
        # An unreadable maildir file is permanent, not transient. Blocking the
        # watermark on it means the window never advances again and systemd
        # restarts the unit every 300s forever.
        def boom(path):
            raise OSError("truncated")
        pms.parse_message = boom
        rc = pms.sync()
        self.assertEqual(self.written, [("uuid-1", 42)])
        self.assertEqual(rc, 0)

    def test_a_failed_upload_does_freeze_the_watermark(self):
        self.api.post_raises = True
        rc = pms.sync()
        self.assertEqual(self.written, [])
        self.assertEqual(rc, 1)


class OrderingTest(unittest.TestCase):
    """Both paginated queries must order by a unique, immutable key.

    Default ordering is -created, which is neither unique nor stable while phase
    1's uploads are landing: each new document inserts by its email Date, in the
    middle of the ordering, pushing one unread row across the next page
    boundary.
    """

    def setUp(self):
        self._real_api = pms.api

    def tearDown(self):
        pms.api = self._real_api

    def test_existing_attachments_orders_by_id(self):
        fake = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [], "next": None},
        ])
        pms.api = fake
        pms.existing_attachments(["a@x"])
        self.assertIn("ordering=id", fake.calls[1][1])

    def test_context_pass_orders_by_id(self):
        fake = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [], "next": None},
        ])
        pms.api = fake
        pms.context_pass()
        self.assertIn("ordering=id", fake.calls[1][1])


class NotmuchQuotingTest(unittest.TestCase):
    def setUp(self):
        self._real_api, self._real_notmuch = pms.api, pms.notmuch

    def tearDown(self):
        pms.api, pms.notmuch = self._real_api, self._real_notmuch

    def test_message_id_is_quoted_in_the_notmuch_query(self):
        # An unquoted id: term containing a space parses as two terms, so
        # paths[0] can be a DIFFERENT message and the wrong body is PATCHed in.
        asked = []
        pms.api = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [doc(10, "we ird@x", "one.pdf")], "next": None},
        ])
        pms.notmuch = lambda *a: asked.append(a) or ""
        pms.context_pass()
        self.assertEqual(asked[0][-1], 'id:"we ird@x"')


class CountedAttachmentsTest(unittest.TestCase):
    def setUp(self):
        self._real_api = pms.api

    def tearDown(self):
        pms.api = self._real_api

    def test_counts_documents_per_msgid_and_filename(self):
        pms.api = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [doc(10, "a@x", "scan.pdf"), doc(11, "a@x", "scan.pdf"),
                         doc(12, "a@x", "other.pdf")],
             "next": None},
        ])
        self.assertEqual(
            pms.existing_attachments(["a@x"]),
            {"a@x": collections.Counter({"scan.pdf": 2, "other.pdf": 1})},
        )


class NextPageTest(unittest.TestCase):
    """paperless builds `next` with request.build_absolute_uri().

    Behind the ingress that comes back as http:// while the configured URL is
    https://, so a naive prefix strip is a no-op and the next request goes to
    https://host/api + the whole absolute URL -- which the ingress answers with
    the SPA's HTML, and the JSON decode blows up. Observed live once the archive
    passed 100 mail documents.
    """

    def test_absolute_next_url_with_a_different_scheme_becomes_a_bare_path(self):
        self.assertEqual(
            pms.next_path(
                "http://paperless.jevy.org/api/documents/"
                "?custom_field_query=%5B%22x%22%5D&ordering=id&page=2"
            ),
            "/documents/?custom_field_query=%5B%22x%22%5D&ordering=id&page=2",
        )

    def test_a_next_url_that_already_matches_is_unchanged(self):
        self.assertEqual(
            pms.next_path("https://paperless.example/api/documents/?page=3"),
            "/documents/?page=3",
        )

    def test_no_next_url_is_falsy(self):
        self.assertIsNone(pms.next_path(None))


class PaginationTest(unittest.TestCase):
    def setUp(self):
        self._real_api = pms.api

    def tearDown(self):
        pms.api = self._real_api

    def test_context_pass_follows_a_cross_scheme_next_url(self):
        fake = FakeApi([
            {"results": [{"id": 2, "name": "Email Message-ID"}]},
            {"results": [], "next": "http://paperless.jevy.org/api/documents/?page=2"},
            {"results": [], "next": None},
        ])
        pms.api = fake
        pms.context_pass()
        self.assertEqual(fake.calls[2][1], "/documents/?page=2")


if __name__ == "__main__":
    unittest.main()


def dup_task(survivor_id, msgid, sender="a@b.com", tags=(783,), corr=7):
    """A consume task paperless rejected as a SHA-256 duplicate."""
    return {
        "status": "failure",
        "result_data": {"duplicate_of": survivor_id},
        "input_data": {
            "filename": "x.pdf",
            "overrides": {
                "title": "the email subject",
                "created": "2005-09-11",
                "tag_ids": list(tags),
                "correspondent_id": corr,
                "custom_fields": {"1": sender, "2": msgid},
            },
        },
    }


class DedupePassRouter:
    """Answers /tasks/ from a page list and /documents/<id>/ from a dict."""

    def __init__(self, task_pages, docs):
        self.task_pages = list(task_pages)
        self.docs = docs
        self.patches = []

    def __call__(self, method, path, **kw):
        if method == "PATCH":
            did = int(path.strip("/").split("/")[-1])
            self.patches.append((did, kw.get("json")))
            return {}
        if path.startswith("/custom_fields/"):
            return {"results": [{"id": 2, "name": "Email Message-ID"}]}
        if path.startswith("/tasks/"):
            return self.task_pages.pop(0)
        if path.startswith("/documents/"):
            return self.docs[int(path.strip("/").split("/")[-1])]
        raise AssertionError(f"unexpected {method} {path}")


class DedupePassTest(unittest.TestCase):
    def setUp(self):
        self._api = pms.api

    def tearDown(self):
        pms.api = self._api

    def survivor(self, did, tags, corr, fields):
        return {"id": did, "tags": list(tags), "correspondent": corr,
                "custom_fields": list(fields), "title": "my filed title",
                "created": "2019-01-01"}

    def test_stamps_a_survivor_that_has_no_message_id(self):
        r = DedupePassRouter(
            [{"results": [dup_task(42, "MSG-1", "vendor@x.com", (783, 785), 7)],
              "next": None}],
            {42: self.survivor(42, [1, 26], None, [])},
        )
        pms.api = r
        pms.dedupe_pass()
        self.assertEqual(len(r.patches), 1)
        did, body = r.patches[0]
        self.assertEqual(did, 42)
        self.assertEqual(body["tags"], [1, 26, 783, 785])
        self.assertEqual(body["correspondent"], 7)
        vals = {f["field"]: f["value"] for f in body["custom_fields"]}
        self.assertEqual(vals[2], "MSG-1")
        self.assertEqual(vals[1], "vendor@x.com")

    def test_never_touches_created_or_title(self):
        r = DedupePassRouter(
            [{"results": [dup_task(42, "MSG-1")], "next": None}],
            {42: self.survivor(42, [1], None, [])},
        )
        pms.api = r
        pms.dedupe_pass()
        _, body = r.patches[0]
        self.assertNotIn("created", body)
        self.assertNotIn("title", body)

    def test_skips_a_survivor_that_already_has_a_message_id(self):
        r = DedupePassRouter(
            [{"results": [dup_task(42, "MSG-1")], "next": None}],
            {42: self.survivor(42, [1, 783], 7,
                               [{"field": 2, "value": "MSG-1"}])},
        )
        pms.api = r
        pms.dedupe_pass()
        self.assertEqual(r.patches, [])

    def test_does_not_overwrite_an_existing_correspondent(self):
        r = DedupePassRouter(
            [{"results": [dup_task(42, "MSG-1", corr=7)], "next": None}],
            {42: self.survivor(42, [1], 99, [])},
        )
        pms.api = r
        pms.dedupe_pass()
        _, body = r.patches[0]
        self.assertNotIn("correspondent", body)

    def test_ignores_failures_that_are_not_duplicates(self):
        r = DedupePassRouter(
            [{"results": [{"status": "failure", "result_data": {"traceback": "boom"},
                           "input_data": {}}], "next": None}],
            {},
        )
        pms.api = r
        pms.dedupe_pass()
        self.assertEqual(r.patches, [])

    def test_paginates_task_history(self):
        r = DedupePassRouter(
            [{"results": [dup_task(42, "MSG-1")],
              "next": "http://paperless.example/api/tasks/?page=2"},
             {"results": [dup_task(43, "MSG-2")], "next": None}],
            {42: self.survivor(42, [1], None, []),
             43: self.survivor(43, [2], None, [])},
        )
        pms.api = r
        pms.dedupe_pass()
        self.assertEqual(sorted(d for d, _ in r.patches), [42, 43])
