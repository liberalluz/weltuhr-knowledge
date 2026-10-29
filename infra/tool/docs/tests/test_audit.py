from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import audit  # noqa: E402


class BaselineTests(unittest.TestCase):
    def _root(self, rows: str) -> Path:
        tmp = Path(tempfile.mkdtemp())
        (tmp / "docs").mkdir()
        (tmp / "docs" / "baselines.md").write_text(
            "# 基线\n\n| 标识 | 锚点提交 | 冻结日期 | 范围（配置项类别） | 明细 | 已知缺口 |\n"
            "|---|---|---|---|---|---|\n" + rows,
            encoding="utf-8",
        )
        return tmp

    def test_valid_baseline(self):
        root = self._root("| `BL-0` | `未登记` | 2026-10-17 | S0 | — | 无 |\n")
        self.assertEqual(audit.check_baseline(root), [])

    def test_duplicate_and_order(self):
        root = self._root(
            "| `BL-1` | `未登记` | 2026-10-17 | S0 | — | 无 |\n"
            "| `BL-1` | `未登记` | 2026-10-17 | S0 | — | 无 |\n"
        )
        errors = audit.check_baseline(root)
        self.assertTrue(any("重复" in error for error in errors))

    def test_bad_date(self):
        root = self._root("| `BL-0` | `未登记` | 2026-99-99 | S0 | — | 无 |\n")
        self.assertTrue(any("日期非法" in error for error in audit.check_baseline(root)))


class BudgetTests(unittest.TestCase):
    def test_budget_pass_and_fail(self):
        tmp = Path(tempfile.mkdtemp())
        (tmp / "docs/specs/controlled").mkdir(parents=True)
        (tmp / "docs/specs/controlled/srs.md").write_text("x" * 10, encoding="utf-8")
        (tmp / "infra/tool/docs").mkdir(parents=True)
        (tmp / "infra/tool/docs/budgets.json").write_text(
            json.dumps({"limits": {"docs/specs/controlled/srs.md": 10}}),
            encoding="utf-8",
        )
        self.assertEqual(audit.check_budget(tmp), [])
        (tmp / "docs/specs/controlled/srs.md").write_text("x" * 11, encoding="utf-8")
        self.assertTrue(any("11 B > 10 B" in error for error in audit.check_budget(tmp)))


if __name__ == "__main__":
    unittest.main()
