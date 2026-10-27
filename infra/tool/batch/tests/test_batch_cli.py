from __future__ import annotations

import contextlib
import io
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import batch  # noqa: E402
import card  # noqa: E402
import check  # noqa: E402


def make_scope(**overrides):
    scope = {
        "batch": "B1",
        "type": "process",
        "allowed": ["infra/tool/batch/**"],
        "forbidden": [],
    }
    scope.update(overrides)
    return check.sign_scope(scope, "tester")


def write_approved_card(target: Path):
    approved = card.approve_card(
        {
            "batch": "B1",
            "type": "process",
            "goal": "test",
            "branch": "process/b1",
            "base": "main",
            "allowed": ["infra/**"],
        },
        "tester",
    )
    card.write_card(target / "card.yaml", approved)


def write_state(root: Path, batch_id: str = "B1"):
    target = root / batch_id
    target.mkdir(parents=True, exist_ok=True)
    (target / "state.json").write_text(
        json.dumps(
            {
                "batch": batch_id,
                "type": "process",
                "branch": "process/c1-batch-cli",
                "base": "main",
            }
        ),
        encoding="utf-8",
    )
    return target


def run(args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        code = batch.main(args)
    return code, out.getvalue()


class StatusTests(unittest.TestCase):
    def test_status_batch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            write_approved_card(target)
            (target / "scope.json").write_text(json.dumps(make_scope()), encoding="utf-8")
            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Batch: B1 (process)", out)
            self.assertIn("Scope: 1 allowed", out)
            self.assertIn("Stage: check", out)

    def test_status_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            write_approved_card(target)
            (target / "scope.json").write_text(json.dumps(make_scope()), encoding="utf-8")
            code, out = run(["--root", str(root), "status", "--batch", "B1", "--json"])
            self.assertEqual(code, 0)
            payload = json.loads(out)
            self.assertEqual(payload["batch"], "B1")
            self.assertEqual(payload["scope"]["approvalError"], None)
            self.assertEqual(payload["stage"], "check")

    def test_status_missing_batch(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run(["--root", tmp, "status", "--batch", "NOPE"])
            self.assertEqual(code, 1)
            self.assertIn("no batch found", out)

    def test_active_points_to_batch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            (root / "active").write_text(str(target), encoding="utf-8")
            code, out = run(["--root", str(root), "status"])
            self.assertEqual(code, 0)
            self.assertIn("Batch: B1", out)

    def test_card_stage(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            (target / "card.yaml").write_text("batch: B1\n", encoding="utf-8")
            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: approve", out)
            self.assertIn("Next: batch approve", out)

    def test_approved_card_without_scope_starts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            approved = card.approve_card(
                {
                    "batch": "B1",
                    "type": "process",
                    "goal": "test",
                    "branch": "process/b1",
                    "base": "main",
                    "allowed": ["infra/**"],
                },
                "tester",
            )
            card.write_card(target / "card.yaml", approved)
            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: start", out)
            self.assertIn("Next: batch start", out)


class ListTests(unittest.TestCase):
    def test_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            (target / "scope.json").write_text(json.dumps(make_scope()), encoding="utf-8")
            code, out = run(["--root", str(root), "list"])
            self.assertEqual(code, 0)
            self.assertIn("B1", out)
            self.assertIn("process", out)

    def test_list_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run(["--root", tmp, "list"])
            self.assertEqual(code, 0)
            self.assertIn("no batches", out)


class OccupancyTests(unittest.TestCase):
    def test_plan_auto_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            code, out = run(
                [
                    "--root",
                    str(root),
                    "plan",
                    "--auto-id",
                    "--type",
                    "process",
                    "--goal",
                    "x",
                    "--allowed",
                    "infra/**",
                ]
            )
            self.assertEqual(code, 0)
            match = re.search(r"\d{8}-[0-9a-f]{6}", out)
            self.assertIsNotNone(match)
            self.assertTrue((root / match.group(0) / "card.yaml").exists())

    def test_start_refuses_other_active(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target1 = root / "B1"
            target1.mkdir()
            write_approved_card(target1)
            self.assertEqual(run(["--root", str(root), "start", "B1", "--no-branch"])[0], 0)

            target2 = root / "B2"
            target2.mkdir()
            approved = card.approve_card(
                {
                    "batch": "B2",
                    "type": "process",
                    "goal": "test",
                    "branch": "process/b2",
                    "base": "main",
                    "allowed": ["infra/**"],
                },
                "tester",
            )
            card.write_card(target2 / "card.yaml", approved)
            code, out = run(["--root", str(root), "start", "B2", "--no-branch"])
            self.assertEqual(code, 1)
            self.assertIn("active batch is B1", out)
            self.assertIn("B1", (root / "active").read_text(encoding="utf-8"))

    def test_start_clear_stale_when_pr_merged(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target1 = root / "B1"
            target1.mkdir()
            write_approved_card(target1)
            self.assertEqual(run(["--root", str(root), "start", "B1", "--no-branch"])[0], 0)

            target2 = root / "B2"
            target2.mkdir()
            approved = card.approve_card(
                {
                    "batch": "B2",
                    "type": "process",
                    "goal": "test",
                    "branch": "process/b2",
                    "base": "main",
                    "allowed": ["infra/**"],
                },
                "tester",
            )
            card.write_card(target2 / "card.yaml", approved)
            with mock.patch.object(batch, "merged_pr_for_branch", return_value=(222, "")):
                code, out = run(
                    ["--root", str(root), "start", "B2", "--no-branch", "--clear-stale"]
                )
            self.assertEqual(code, 0)
            self.assertIn("clearing stale active B1", out)
            self.assertIn("B2", (root / "active").read_text(encoding="utf-8"))

    def test_start_clear_stale_requires_merged_pr(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target1 = root / "B1"
            target1.mkdir()
            write_approved_card(target1)
            self.assertEqual(run(["--root", str(root), "start", "B1", "--no-branch"])[0], 0)

            target2 = root / "B2"
            target2.mkdir()
            approved = card.approve_card(
                {
                    "batch": "B2",
                    "type": "process",
                    "goal": "test",
                    "branch": "process/b2",
                    "base": "main",
                    "allowed": ["infra/**"],
                },
                "tester",
            )
            card.write_card(target2 / "card.yaml", approved)
            with mock.patch.object(batch, "merged_pr_for_branch", return_value=(0, "OPEN")):
                code, out = run(
                    ["--root", str(root), "start", "B2", "--no-branch", "--clear-stale"]
                )
            self.assertEqual(code, 1)
            self.assertIn("no merged PR", out)
            self.assertIn("B1", (root / "active").read_text(encoding="utf-8"))

    def test_status_reports_active(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_state(root)
            (root / "active").write_text(str(target), encoding="utf-8")
            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Active: yes", out)

    def test_list_marks_active_and_orders_latest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first = write_state(root, "B1")
            second = write_state(root, "B2")
            (first / "state.json").write_text(
                json.dumps(
                    {
                        "batch": "B1",
                        "type": "process",
                        "created_at": "2026-10-01T00:00:00+00:00",
                    }
                ),
                encoding="utf-8",
            )
            (second / "state.json").write_text(
                json.dumps(
                    {
                        "batch": "B2",
                        "type": "process",
                        "created_at": "2026-10-02T00:00:00+00:00",
                    }
                ),
                encoding="utf-8",
            )
            (root / "active").write_text(str(second), encoding="utf-8")
            code, out = run(["--root", str(root), "list"])
            self.assertEqual(code, 0)
            self.assertIn("* B2", out)
            self.assertLess(out.index("* B2"), out.index("B1"))


class PrivacyTests(unittest.TestCase):
    def test_planned_steps_use_short_python_name(self):
        steps = batch.planned_steps(
            [".agents/skills/batch/SKILL.md"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        command = next(cmd for name, cmd, _ in steps if name == "skills")
        self.assertIn(command[0], {"python", "python3"})
        self.assertNotIn("Users", command[0])
        self.assertNotIn("AppData", command[0])


if __name__ == "__main__":
    unittest.main()
