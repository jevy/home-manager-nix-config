#!/usr/bin/env python3
"""Unit tests for paperless-mail-sync.

Run with:  python3 -m unittest discover -s modules/services -p 'test_*.py'

The module reads its config, state dir and token from the environment at import
time (it is a systemd-wrapped script, not a library), so those are faked here
before the import. Every HTTP call goes through `api()`, which is the single
seam these tests replace.
"""

from __future__ import annotations

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
            {("a@x", "one.pdf"), ("a@x", "two.pdf")},
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
        self.assertEqual(pms.existing_attachments([]), set())
        self.assertEqual(fake.calls, [])

    def test_missing_custom_field_is_not_an_error(self):
        fake = FakeApi([{"results": []}])
        pms.api = fake
        self.assertEqual(pms.existing_attachments(["a@x"]), set())


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


if __name__ == "__main__":
    unittest.main()
