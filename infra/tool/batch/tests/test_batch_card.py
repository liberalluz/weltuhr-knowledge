from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import batch  # noqa: E402
import card  # noqa: E402
import check  # noqa: E402


def run(args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        code = batch.main(args)
    return code, out.getvalue()


def make_card(**overrides):
    value = {
        "batch": "B1",
        "type": "process",
        "goal": "test: a goal with a colon",
        "branch": "process/B1",
        "base": "main",
        "allowed": ["infra/tool/batch/**"],
        "forbidden": [],
        "acceptance": ["tests pass"],
        "platforms": ["none"],
        "docs": "none",
        "size_budget": 400,
    }
    value.update(overrides)
    return value


class CardTests(unittest.TestCase):
    def test_roundtrip_and_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "card.yaml"
            approved = card.approve_card(make_card(), "tester")
            card.write_card(path, approved)
            loaded = card.read_card(path)
            self.assertEqual(loaded["goal"], make_card()["goal"])
            self.assertEqual(loaded["allowed"], ["infra/tool/batch/**"])
            self.assertEqual(card.verify_card(loaded), None)

    def test_edit_invalidates_hash(self):
        approved = card.approve_card(make_card(), "tester")
        approved["allowed"].append("app/rogue.dart")
        self.assertIn("hash 不匹配", card.verify_card(approved) or "")

    def test_missing_approval(self):
        self.assertIn("未批准", card.verify_card(make_card()) or "")


class PlanTests(unittest.TestCase):
    def test_plan_writes_draft(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            code, out = run(
                [
                    "--root",
                    str(root),
                    "plan",
                    "B1",
                    "--type",
                    "process",
                    "--goal",
                    "test goal",
                    "--allowed",
                    "infra/tool/batch/**",
                    "--acceptance",
                    "tests pass",
                    "--base",
                    "main",
                ]
            )
            self.assertEqual(code, 0)
            self.assertIn("card draft", out)
            loaded = card.read_card(root / "B1" / "card.yaml")
            self.assertEqual(loaded["batch"], "B1")
            self.assertEqual(loaded["allowed"], ["infra/tool/batch/**"])
            self.assertNotIn("approval", loaded)

    def test_plan_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            args = ["--root", str(root), "plan", "B1", "--type", "process", "--goal", "x", "--allowed", "infra/**"]
            self.assertEqual(run(args)[0], 0)
            self.assertEqual(run(args)[0], 1)


class ApproveStartTests(unittest.TestCase):
    def test_approve_requires_confirmation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            run(["--root", str(root), "plan", "B1", "--type", "process", "--goal", "x", "--allowed", "infra/**"])
            self.assertEqual(run(["--root", str(root), "approve", "B1"])[0], 2)
            self.assertEqual(
                run(["--root", str(root), "approve", "B1", "--chat", "--confirm", "00000000"])[0],
                1,
            )

    def test_approve_and_start_no_branch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            run(
                [
                    "--root",
                    str(root),
                    "plan",
                    "B1",
                    "--type",
                    "process",
                    "--goal",
                    "x",
                    "--allowed",
                    "infra/tool/batch/**",
                    "--base",
                    "main",
                ]
            )
            digest = card.card_hash(card.read_card(root / "B1" / "card.yaml"))
            code, out = run(
                ["--root", str(root), "approve", "B1", "--chat", "--confirm", digest[:8]]
            )
            self.assertEqual(code, 0)
            self.assertIn("approved B1", out)
            self.assertIn("via chat", out)

            code, out = run(["--root", str(root), "start", "B1", "--no-branch"])
            self.assertEqual(code, 0)
            target = root / "B1"
            self.assertTrue((target / "state.json").exists())
            self.assertTrue((target / "scope.json").exists())
            self.assertTrue((target / "card.yaml").exists())
            self.assertIn(str(target), (root / "active").read_text(encoding="utf-8"))

            scope_path = check.resolve_scope(target)
            self.assertEqual(scope_path.name, "scope.json")
            scope = check.load_scope(scope_path)
            self.assertIsNone(check.verify_scope(scope))

            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: check", out)

    def test_start_without_approval_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            run(["--root", str(root), "plan", "B1", "--type", "process", "--goal", "x", "--allowed", "infra/**"])
            self.assertEqual(run(["--root", str(root), "start", "B1", "--no-branch"])[0], 1)


if __name__ == "__main__":
    unittest.main()
