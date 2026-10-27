from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "batch"))

import check  # noqa: E402
import pr_metrics  # noqa: E402


def pr(number: int = 1, branch: str = "process/b1") -> dict:
    return {
        "number": number,
        "title": "test",
        "url": "https://example.test/1",
        "headRefName": branch,
        "createdAt": "2026-10-01T10:00:00Z",
        "mergedAt": "2026-10-02T10:00:00Z",
    }


def detail(paths: list[str], commits: int = 1, review: bool = True) -> dict:
    times = ["2026-10-01T10:30:00Z", "2026-10-01T13:30:00Z"][:commits]
    return {
        "files": [{"path": p} for p in paths],
        "commits": [{"committedDate": t} for t in times],
        "reviews": (
            [{"state": "APPROVED", "submittedAt": "2026-10-01T12:00:00Z"}]
            if review
            else []
        ),
    }


class RecordTests(unittest.TestCase):
    def test_lead_docs_and_unknown_scope(self):
        record = pr_metrics.build_record(
            pr(), detail(["app/lib/a.dart", "docs/specs/a.md"]), {"by_branch": {}, "by_pr": {}}
        )
        assert record is not None
        self.assertEqual(record["leadHours"], 24.0)
        self.assertEqual(record["docsShare"], 0.5)
        self.assertEqual(record["scopeStatus"], "unknown")
        self.assertEqual(record["week"], "2026-W40")

    def test_rework_after_review(self):
        record = pr_metrics.build_record(
            pr(), detail(["app/lib/a.dart"], commits=2), {"by_branch": {}, "by_pr": {}}
        )
        assert record is not None
        self.assertEqual(record["postReviewCommits"], 1)
        self.assertTrue(record["rework"])

    def test_scope_pass_and_fail(self):
        scope = check.sign_scope(
            {
                "batch": "B1",
                "type": "process",
                "allowed": ["infra/**"],
                "forbidden": [],
            },
            "tester",
        )
        scopes = {"by_branch": {"process/b1": scope}, "by_pr": {}}
        ok = pr_metrics.build_record(pr(), detail(["infra/a.py"]), scopes)
        bad = pr_metrics.build_record(pr(), detail(["app/lib/a.dart"]), scopes)
        assert ok is not None and bad is not None
        self.assertEqual(ok["scopeStatus"], "pass")
        self.assertEqual(bad["scopeStatus"], "fail")
        self.assertTrue(bad["scopeViolations"])


class WeekTests(unittest.TestCase):
    def test_group_week(self):
        scope = {"by_branch": {}, "by_pr": {}}
        records = []
        for number, merged in ((1, "2026-10-02T10:00:00Z"), (2, "2026-10-03T10:00:00Z")):
            base = pr(number)
            base["mergedAt"] = merged
            record = pr_metrics.build_record(base, detail(["docs/a.md"]), scope)
            assert record is not None
            records.append(record)
        weeks = pr_metrics.group_weeks(records)
        self.assertEqual(len(weeks), 1)
        self.assertEqual(weeks[0]["merged"], 2)
        self.assertEqual(weeks[0]["docsShare"], 1.0)
        self.assertEqual(weeks[0]["scopeKnown"], 0)


if __name__ == "__main__":
    unittest.main()
