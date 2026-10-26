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
            "goal": "test",
            "branch": "process/B1",
            "base": "main",
            "allowed": ["infra/**"],
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
            "platforms": [],
            "docs": "none",
        },
        "tester",
    )
    (target / "scope.json").write_text(json.dumps(scope), encoding="utf-8")
    (target / "evidence.log").write_text("RESULT: PASS\n", encoding="utf-8")
    (root / "active").write_text(str(target), encoding="utf-8")
    return target


class MergeGuardTests(unittest.TestCase):
    def test_requires_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root)
            (target / "evidence.log").unlink()
            code, out = run(["--root", str(root), "merge", "--pr", "1", "--yes"])
            self.assertEqual(code, 1)
            self.assertIn("evidence", out)

    def test_requires_yes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            code, out = run(["--root", str(root), "merge", "--pr", "1"])
            self.assertEqual(code, 2)
            self.assertIn("--yes", out)

    def test_head_mismatch_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            with mock.patch.object(
                batch,
                "run_gh",
                return_value=(0, '{"headRefName":"other","state":"OPEN","number":1}', ""),
            ), mock.patch.object(batch, "run_merge_gate") as gate:
                code, out = run(["--root", str(root), "merge", "--pr", "1", "--yes"])
            self.assertEqual(code, 1)
            self.assertIn("refusing merge", out)
            gate.assert_not_called()


class MergeRunTests(unittest.TestCase):
    def test_dry_run_does_not_record(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            with mock.patch.object(
                batch,
                "run_gh",
                return_value=(0, '{"headRefName":"process/B1","state":"OPEN","number":1}', ""),
            ), mock.patch.object(batch, "run_merge_gate", return_value=0) as gate:
                code, out = run(["--root", str(root), "merge", "--pr", "1", "--dry-run"])
            self.assertEqual(code, 0)
            self.assertIn("not merged", out)
            gate.assert_called_once_with(1, yes=False, dry_run=True)
            self.assertFalse((root / "B1" / "merge.json").exists())

    def test_success_records_merge_and_clears_active(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            views = [
                (0, '{"headRefName":"process/B1","state":"OPEN","number":1}', ""),
                (0, '{"number":1,"title":"t","mergeCommit":{"oid":"abc"},"state":"MERGED"}', ""),
            ]
            with mock.patch.object(batch, "run_gh", side_effect=views), mock.patch.object(
                batch, "run_merge_gate", return_value=0
            ):
                code, out = run(["--root", str(root), "merge", "--pr", "1", "--yes"])
            self.assertEqual(code, 0)
            record = json.loads((root / "B1" / "merge.json").read_text(encoding="utf-8"))
            self.assertEqual(record["pr"], 1)
            self.assertEqual(record["sha"], "abc")
            self.assertFalse((root / "active").exists())

            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: merged", out)
            self.assertIn("Merged: PR #1 abc", out)

    def test_gate_failure_does_not_record(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root)
            with mock.patch.object(
                batch,
                "run_gh",
                return_value=(0, '{"headRefName":"process/B1","state":"OPEN","number":1}', ""),
            ), mock.patch.object(batch, "run_merge_gate", return_value=1):
                code, _ = run(["--root", str(root), "merge", "--pr", "1", "--yes"])
            self.assertEqual(code, 1)
            self.assertFalse((root / "B1" / "merge.json").exists())


if __name__ == "__main__":
    unittest.main()
