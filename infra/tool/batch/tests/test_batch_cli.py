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


if __name__ == "__main__":
    unittest.main()
