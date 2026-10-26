from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import merge  # noqa: E402


def make_pr(**overrides):
    pr = {
        "number": 190,
        "url": "https://github.com/liberalluz/weltuhr-knowledge/pull/190",
        "title": "docs(repo): test",
        "state": "OPEN",
        "isDraft": False,
        "mergeable": "MERGEABLE",
        "mergeStateStatus": "CLEAN",
        "reviewDecision": "",
        "statusCheckRollup": [
            {"name": "app-checks", "status": "COMPLETED", "conclusion": "SUCCESS"},
            {"name": "content-checks", "status": "COMPLETED", "conclusion": "SUCCESS"},
            {"name": "repo-hygiene", "status": "COMPLETED", "conclusion": "SUCCESS"},
        ],
    }
    pr.update(overrides)
    return pr


class EvaluateTests(unittest.TestCase):
    def test_clean_pr_is_eligible(self):
        verdict = merge.evaluate(make_pr())
        self.assertTrue(verdict.eligible)
        self.assertEqual(verdict.passed, 3)
        self.assertEqual(verdict.failed, 0)
        self.assertEqual(verdict.pending, 0)

    def test_failed_check_blocks(self):
        pr = make_pr()
        pr["statusCheckRollup"][0]["conclusion"] = "FAILURE"
        verdict = merge.evaluate(pr)
        self.assertFalse(verdict.eligible)
        self.assertEqual(verdict.failed, 1)
        self.assertTrue(any("检查失败" in b for b in verdict.blockers))

    def test_pending_check_blocks(self):
        pr = make_pr()
        pr["statusCheckRollup"][1]["status"] = "IN_PROGRESS"
        pr["statusCheckRollup"][1]["conclusion"] = ""
        verdict = merge.evaluate(pr)
        self.assertFalse(verdict.eligible)
        self.assertEqual(verdict.pending, 1)

    def test_no_checks_blocks(self):
        verdict = merge.evaluate(make_pr(statusCheckRollup=[]))
        self.assertFalse(verdict.eligible)
        self.assertTrue(any("没有任何检查" in b for b in verdict.blockers))

    def test_draft_blocks(self):
        verdict = merge.evaluate(make_pr(isDraft=True))
        self.assertFalse(verdict.eligible)
        self.assertTrue(any("draft" in b for b in verdict.blockers))

    def test_conflicting_blocks(self):
        verdict = merge.evaluate(make_pr(mergeable="CONFLICTING"))
        self.assertFalse(verdict.eligible)

    def test_unstable_merge_state_blocks(self):
        verdict = merge.evaluate(make_pr(mergeStateStatus="UNSTABLE"))
        self.assertFalse(verdict.eligible)

    def test_changes_requested_blocks(self):
        verdict = merge.evaluate(make_pr(reviewDecision="CHANGES_REQUESTED"))
        self.assertFalse(verdict.eligible)

    def test_review_required_blocks(self):
        verdict = merge.evaluate(make_pr(reviewDecision="REVIEW_REQUIRED"))
        self.assertFalse(verdict.eligible)

    def test_status_context_success(self):
        pr = make_pr(
            statusCheckRollup=[
                {"context": "deploy", "state": "SUCCESS", "targetUrl": "https://example.test"}
            ]
        )
        verdict = merge.evaluate(pr)
        self.assertTrue(verdict.eligible)
        self.assertEqual(verdict.passed, 1)

    def test_status_context_pending(self):
        pr = make_pr(statusCheckRollup=[{"context": "deploy", "state": "PENDING"}])
        verdict = merge.evaluate(pr)
        self.assertFalse(verdict.eligible)
        self.assertEqual(verdict.pending, 1)

    def test_unknown_conclusion_blocks(self):
        pr = make_pr()
        pr["statusCheckRollup"][0]["conclusion"] = "SOMETHING_NEW"
        verdict = merge.evaluate(pr)
        self.assertFalse(verdict.eligible)
        self.assertEqual(verdict.failed, 1)

    def test_stale_cancelled_run_is_ignored(self):
        pr = make_pr(
            statusCheckRollup=[
                {
                    "name": "app-checks",
                    "status": "COMPLETED",
                    "conclusion": "CANCELLED",
                    "completedAt": "2026-10-26T12:00:00Z",
                },
                {
                    "name": "app-checks",
                    "status": "COMPLETED",
                    "conclusion": "SUCCESS",
                    "completedAt": "2026-10-26T12:01:00Z",
                },
                {"name": "content-checks", "status": "COMPLETED", "conclusion": "SUCCESS"},
                {"name": "repo-hygiene", "status": "COMPLETED", "conclusion": "SUCCESS"},
            ]
        )
        verdict = merge.evaluate(pr)
        self.assertTrue(verdict.eligible)
        self.assertEqual(verdict.passed, 3)
        self.assertEqual(verdict.failed, 0)

    def test_newest_failed_run_still_blocks(self):
        pr = make_pr(
            statusCheckRollup=[
                {
                    "name": "app-checks",
                    "status": "COMPLETED",
                    "conclusion": "SUCCESS",
                    "completedAt": "2026-10-26T12:00:00Z",
                },
                {
                    "name": "app-checks",
                    "status": "COMPLETED",
                    "conclusion": "FAILURE",
                    "completedAt": "2026-10-26T12:01:00Z",
                },
                {"name": "content-checks", "status": "COMPLETED", "conclusion": "SUCCESS"},
                {"name": "repo-hygiene", "status": "COMPLETED", "conclusion": "SUCCESS"},
            ]
        )
        verdict = merge.evaluate(pr)
        self.assertFalse(verdict.eligible)
        self.assertEqual(verdict.failed, 1)
        self.assertTrue(any("检查失败" in blocker for blocker in verdict.blockers))


class CliTests(unittest.TestCase):
    def test_dry_run_returns_zero_when_ready(self):
        with mock.patch.object(merge, "fetch_pr", return_value=make_pr()):
            self.assertEqual(merge.main(["--pr", "190", "--dry-run"]), 0)

    def test_blocked_returns_one(self):
        with mock.patch.object(merge, "fetch_pr", return_value=make_pr(isDraft=True)):
            self.assertEqual(merge.main(["--pr", "190", "--dry-run"]), 1)

    def test_requires_yes(self):
        with mock.patch.object(merge, "fetch_pr", return_value=make_pr()):
            self.assertEqual(merge.main(["--pr", "190"]), 2)

    def test_yes_merges_and_logs_when_ready(self):
        with mock.patch.object(merge, "fetch_pr", return_value=make_pr()), mock.patch.object(
            merge, "merge_pr"
        ) as merge_pr, mock.patch.object(merge, "log_merge") as log_merge:
            self.assertEqual(merge.main(["--pr", "190", "--yes"]), 0)
        merge_pr.assert_called_once_with(190, None)
        log_merge.assert_called_once()

    def test_yes_does_not_merge_when_blocked(self):
        with mock.patch.object(
            merge, "fetch_pr", return_value=make_pr(isDraft=True)
        ), mock.patch.object(merge, "merge_pr") as merge_pr:
            self.assertEqual(merge.main(["--pr", "190", "--yes"]), 1)
        merge_pr.assert_not_called()

    def test_yes_and_dry_run_are_exclusive(self):
        with self.assertRaises(SystemExit):
            merge.main(["--pr", "190", "--yes", "--dry-run"])


if __name__ == "__main__":
    unittest.main()
