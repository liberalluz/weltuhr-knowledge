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


def write_batch(root: Path, allowed: list[str]):
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
            "allowed": allowed,
        },
        "tester",
    )
    card.write_card(target / "card.yaml", approved)
    scope = check.sign_scope(
        {
            "batch": "B1",
            "type": "process",
            "allowed": allowed,
            "forbidden": [],
            "acceptance": [],
            "platforms": [],
            "docs": "none",
        },
        "tester",
    )
    (target / "scope.json").write_text(json.dumps(scope), encoding="utf-8")
    (root / "active").write_text(str(target), encoding="utf-8")
    return target


class PlanTests(unittest.TestCase):
    def test_app_paths_add_flutter_steps(self):
        steps = batch.planned_steps(
            ["app/lib/a.dart"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        names = [name for name, _, _ in steps]
        self.assertEqual(names, ["format", "analyze", "lint", "tests"])

    def test_docs_paths_add_docs_step(self):
        steps = batch.planned_steps(
            ["docs/specs/x.md"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        self.assertEqual([name for name, _, _ in steps], ["docs"])

    def test_quick_has_no_steps(self):
        steps = batch.planned_steps(
            ["app/lib/a.dart"],
            "main",
            quick=True,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        self.assertEqual(steps, [])

    def test_no_tests_skips_tests(self):
        steps = batch.planned_steps(
            ["app/lib/a.dart"],
            "main",
            quick=False,
            no_tests=True,
            no_format=False,
            pr_body=None,
        )
        self.assertNotIn("tests", [name for name, _, _ in steps])


class CheckTests(unittest.TestCase):
    def test_check_passes_and_writes_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**"])
            code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 0)
            self.assertIn("result: PASS", out)
            evidence = (target / "evidence.log").read_text(encoding="utf-8")
            self.assertIn("scope=PASS", evidence)
            self.assertIn("RESULT: PASS", evidence)

            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: pr", out)

    def test_scope_failure_does_not_allow_pr(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["app/**"])
            code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 1)
            self.assertIn("scope=FAIL", (target / "evidence.log").read_text(encoding="utf-8"))
            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: check", out)

    def test_quick_scope_only_does_not_write_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**"])
            code, _ = run(["--root", str(root), "check", "--batch", "B1", "--base", "main", "--quick"])
            self.assertEqual(code, 0)
            self.assertFalse((target / "evidence.log").exists())

    def test_dry_run_does_not_write_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**"])
            code, out = run(
                ["--root", str(root), "check", "--batch", "B1", "--base", "main", "--dry-run"]
            )
            self.assertEqual(code, 0)
            self.assertIn("[ok] scope", out)
            self.assertFalse((target / "evidence.log").exists())


if __name__ == "__main__":
    unittest.main()
