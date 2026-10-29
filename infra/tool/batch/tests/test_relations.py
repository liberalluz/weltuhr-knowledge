from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import relations  # noqa: E402


class RequiredClassesTests(unittest.TestCase):
    def test_batch_only(self):
        self.assertEqual(relations.required_classes([], []), [])

    def test_adr_spec_cases_from_paths(self):
        got = relations.required_classes(
            [
                "docs/decisions/0013-x.md",
                "docs/specs/SRS-learning.md",
                "app/test/core/x_test.dart",
            ],
            [],
        )
        self.assertEqual(got, ["ADR", "规格条", "用例"])

    def test_todo_from_added_line(self):
        got = relations.required_classes(
            ["app/lib/x.dart"],
            ["  // TODO(confirm): threshold pending"],
        )
        self.assertIn("待确认事项", got)

    def test_pr_link_from_added_line(self):
        got = relations.required_classes(
            ["app/lib/x.dart"],
            ["See [#200](https://github.com/liberalluz/weltuhr-knowledge/pull/200)."],
        )
        self.assertIn("PR", got)

    def test_card_links_drive_milestone_issue_pr(self):
        card = {"milestone": "P1", "issues": ["123"], "related_prs": ["200"]}
        got = relations.required_classes([], [], card=card)
        self.assertEqual(got, ["里程碑", "issue", "PR"])

    def test_missing_classes(self):
        body = "## 关联\n\n- 批次号：`B1`\n"
        self.assertEqual(
            relations.missing_classes(body, ["批次号", "ADR"]), ["ADR"]
        )


if __name__ == "__main__":
    unittest.main()
