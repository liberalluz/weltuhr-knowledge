from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import batch  # noqa: E402
import card  # noqa: E402
import check  # noqa: E402


def run(args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        code = batch.main(args)
    return code, out.getvalue()


def write_batch(root: Path):
    target = root / "B1"
    target.mkdir(parents=True, exist_ok=True)
    (target / "state.json").write_text(
        json.dumps({"batch": "B1", "type": "process", "branch": "process/B1", "base": "main"}),
        encoding="utf-8",
    )
    approved = card.approve_card(
        {
            "batch": "B1",
            "type": "process",
            "goal": "test goal",
            "branch": "process/B1",
            "base": "main",
            "allowed": ["infra/**"],
            "platforms": ["none"],
        },
        "tester",
    )
    card.write_card(target / "card.yaml", approved)
    scope = check.sign_scope(
        {
            "batch": "B1",
            "type": "process",
            "allowed": ["infra/**"],
            "forbidden": [],
            "acceptance": [],
            "platforms": ["none"],
            "docs": "none",
        },
        "tester",
    )
    (target / "scope.json").write_text(json.dumps(scope), encoding="utf-8")
    (target / "evidence.log").write_text(
        "# batch check B1\nscope=PASS\n$ python test\nexit=0\nRESULT: PASS\n",
        encoding="utf-8",
    )
    (root / "active").write_text(str(target), encoding="utf-8")
    return target


class BuildBodyTests(unittest.TestCase):
    def test_body_has_v2_sections_and_counts(self):
        card_data = {
            "batch": "B1",
            "type": "process",
            "goal": "make the thing",
            "base": "main",
            "allowed": ["infra/**", "docs/**"],
            "platforms": ["windows", "macos"],
        }
        body = batch.build_pr_body(card_data, ["infra/a.py", "docs/b.md"], "scope=PASS\nRESULT: PASS\n")
        for section in (
            "## 变更摘要",
            "## 影响面",
            "## 自审留痕",
            "## 验证",
            "## UI 证据",
            "## 交付物",
            "## AI 参与",
            "## 关联",
            "## 评审提示",
        ):
            self.assertIn(section, body)
        self.assertIn("动了 `2` 条路径，归为 `2` 项；未动 `0` 处", body)
        self.assertNotIn("windows, macos", body)
        self.assertIn("  - Windows：未测 —— ", body)
        self.assertIn("  - macOS：未测 —— ", body)
        self.assertIn("RESULT: PASS", body)
        # One stack (infra) plus docs: the tech-stack group stays out entirely.
        self.assertNotIn("技术栈", body)
        self.assertNotIn("| 模块 | 是否改动 | 说明 |", body)

    def test_stack_group_appears_when_diff_spans_two_stacks(self):
        card_data = {"batch": "B1", "type": "process", "goal": "g", "base": "main"}
        body = batch.build_pr_body(
            card_data, ["app/lib/a.dart", "infra/b.py"], "RESULT: PASS\n"
        )
        self.assertIn("- **技术栈**：", body)
        self.assertIn("| 模块 | 是否改动 | 说明 |", body)
        self.assertIn("| app | 是 |", body)
        self.assertIn("| infra | 是 |", body)
        self.assertIn("| server | 否 |", body)
        self.assertIn("| content | 否 |", body)

    def test_platform_none_writes_group_line_without_children(self):
        body = batch.build_pr_body(
            {"batch": "B1", "type": "process", "goal": "g", "base": "main", "platforms": ["none"]},
            ["infra/a.py"],
            "RESULT: PASS\n",
        )
        self.assertIn("- **平台**：无", body)
        self.assertNotIn("未测 —— card 声明", body)


class CommandPrTests(unittest.TestCase):
    def test_dry_run_writes_body_without_create(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            with mock.patch.object(batch, "validate_body", return_value=0):
                code, out = run(["--root", str(root), "pr", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 0)
            self.assertIn("body validated", out)
            self.assertTrue((root / "B1" / "pr-body.md").exists())

    def test_create_requires_yes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            with mock.patch.object(batch, "validate_body", return_value=0):
                code, _ = run(
                    ["--root", str(root), "pr", "--batch", "B1", "--base", "main", "--create"]
                )
            self.assertEqual(code, 2)

    def test_create_calls_gh(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            with mock.patch.object(batch, "validate_body", return_value=0), mock.patch.object(
                batch, "run_gh", return_value=(0, "https://github.com/x/y/pull/1", "")
            ) as gh:
                code, out = run(
                    ["--root", str(root), "pr", "--batch", "B1", "--base", "main", "--create", "--yes"]
                )
            self.assertEqual(code, 0)
            self.assertIn("pull/1", out)
            self.assertEqual(gh.call_args.args[0][:2], ["pr", "create"])

    def test_missing_evidence_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root)
            (target / "evidence.log").unlink()
            code, out = run(["--root", str(root), "pr", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 1)
            self.assertIn("evidence", out)


if __name__ == "__main__":
    unittest.main()
