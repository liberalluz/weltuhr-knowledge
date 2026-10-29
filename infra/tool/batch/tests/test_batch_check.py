from __future__ import annotations

import contextlib
import io
import json
import os
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


def write_batch(root: Path, allowed: list[str], size_budget: int | None = None):
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
            **({"size_budget": size_budget} if size_budget is not None else {}),
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

    def test_test_paths_also_add_docs_step(self):
        # D1-D3 pair the ledger with test landing points under app/test/, so a
        # test-only change can still leave an unregistered case -- keying the
        # step on the `docs/` prefix alone skips exactly that case.
        steps = batch.planned_steps(
            ["app/test/core/pack/x_test.dart"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        self.assertIn("docs", [name for name, _, _ in steps])

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

    def test_skills_paths_add_skills_step(self):
        steps = batch.planned_steps(
            [".agents/skills/x/SKILL.md"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        self.assertEqual([name for name, _, _ in steps], ["skills"])

    def test_pr_body_adds_pr_body_step(self):
        steps = batch.planned_steps(
            ["infra/a.py"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=Path("/tmp/pr-body.md"),
        )
        self.assertEqual([name for name, _, _ in steps], ["pr-body"])

    def test_no_format_skips_format(self):
        steps = batch.planned_steps(
            ["app/lib/a.dart"],
            "main",
            quick=False,
            no_tests=False,
            no_format=True,
            pr_body=None,
        )
        self.assertNotIn("format", [name for name, _, _ in steps])

    def test_process_paths_select_no_steps(self):
        steps = batch.planned_steps(
            [".github/CONTRIBUTING.md"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        self.assertEqual(steps, [])

    def test_batch_tooling_paths_add_self_tests(self):
        steps = batch.planned_steps(
            ["infra/tool/batch/batch.py"],
            "main",
            quick=False,
            no_tests=False,
            no_format=False,
            pr_body=None,
        )
        names = [name for name, _, _ in steps]
        self.assertEqual(sum(1 for name in names if name.startswith("batch-tests/")), 8)
        self.assertIn("pr-body-self-test", names)


class CheckTests(unittest.TestCase):
    def test_check_passes_and_writes_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**", ".agents/**"])
            with mock.patch.object(batch, "changed_paths", return_value=["infra/a.py"]):
                code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 0)
            self.assertIn("result: PASS", out)
            evidence = (target / "evidence.log").read_text(encoding="utf-8")
            self.assertIn("scope=PASS", evidence)
            self.assertIn("RESULT: PASS", evidence)

            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: pr", out)

    def test_size_budget_blocks_when_over(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root, ["infra/**"], size_budget=10)
            with mock.patch.object(batch, "changed_paths", return_value=["infra/a.py"]), \
                    mock.patch.object(batch, "diff_line_count", return_value=11):
                code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 1)
            self.assertIn("size budget: 11 lines > 10", out)

    def test_size_budget_passes_when_equal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_batch(root, ["infra/**"], size_budget=10)
            with mock.patch.object(batch, "changed_paths", return_value=["infra/a.py"]), \
                    mock.patch.object(batch, "diff_line_count", return_value=10):
                code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 0)
            self.assertIn("size budget: 10 lines <= 10", out)

    def test_changelog_required_for_feat(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            batch_dir = root / ".batch" / "B1"
            batch_dir.mkdir(parents=True)
            card = {"batch": "B1", "type": "feat"}
            self.assertIn("缺 changelog.d/B1.md", batch.changelog_error(root, batch_dir, card))
            (root / "changelog.d").mkdir()
            (root / "changelog.d" / "B1.md").write_text("- 说明：加功能\n", encoding="utf-8")
            self.assertIsNone(batch.changelog_error(root, batch_dir, card))

    def test_changelog_not_required_for_process(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            batch_dir = root / ".batch" / "B1"
            batch_dir.mkdir(parents=True)
            self.assertIsNone(batch.changelog_error(root, batch_dir, {"batch": "B1", "type": "process"}))

    def test_scope_failure_does_not_allow_pr(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["app/**"])
            with mock.patch.object(batch, "changed_paths", return_value=["infra/a.py"]):
                code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 1)
            self.assertIn("scope=FAIL", (target / "evidence.log").read_text(encoding="utf-8"))
            code, out = run(["--root", str(root), "status", "--batch", "B1"])
            self.assertEqual(code, 0)
            self.assertIn("Stage: check", out)

    def test_quick_scope_only_does_not_write_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**", ".agents/**"])
            with mock.patch.object(batch, "changed_paths", return_value=["infra/a.py"]):
                code, _ = run(["--root", str(root), "check", "--batch", "B1", "--base", "main", "--quick"])
            self.assertEqual(code, 0)
            self.assertFalse((target / "evidence.log").exists())

    def test_dry_run_does_not_write_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**", ".agents/**"])
            with mock.patch.object(batch, "changed_paths", return_value=["infra/a.py"]):
                code, out = run(
                    ["--root", str(root), "check", "--batch", "B1", "--base", "main", "--dry-run"]
                )
            self.assertEqual(code, 0)
            self.assertIn("[ok] scope", out)
            self.assertFalse((target / "evidence.log").exists())

    def test_steps_run_and_failure_turns_red(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["app/**"])
            calls = []

            def passing(command, cwd):
                calls.append(list(command))
                return 0, "ok", ""

            with (
                mock.patch.object(batch, "changed_paths", return_value=["app/lib/a.dart"]),
                mock.patch.object(batch, "run_command", side_effect=passing),
            ):
                code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 0)
            self.assertIn("result: PASS", out)
            self.assertTrue(calls, "selected steps were not executed")
            self.assertIn("flutter", [command[0] for command in calls])

            def failing(command, cwd):
                return 1, "", "boom"

            with (
                mock.patch.object(batch, "changed_paths", return_value=["app/lib/a.dart"]),
                mock.patch.object(batch, "run_command", side_effect=failing),
            ):
                code, out = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 1)
            self.assertIn("result: FAIL", out)
            self.assertIn("RESULT: FAIL", (target / "evidence.log").read_text(encoding="utf-8"))


class DisplayTests(unittest.TestCase):
    """Commands are executed with host paths but must never be shown with them."""

    OUTSIDE = r"C:\Program Files\Git\bin\bash.exe" if os.name == "nt" else "/usr/bin/bash"

    def test_inside_repo_path_becomes_relative(self):
        inside = str(batch.REPO_ROOT / "app" / "tool" / "x.dart")
        self.assertEqual(batch.display_path(inside), "app/tool/x.dart")

    def test_repo_root_becomes_dot(self):
        self.assertEqual(batch.display_path(batch.REPO_ROOT), ".")

    def test_outside_path_keeps_only_the_file_name(self):
        self.assertEqual(batch.display_path(self.OUTSIDE), Path(self.OUTSIDE).name)

    def test_relative_path_is_untouched(self):
        self.assertEqual(batch.display_command(["python", "infra/a.py"]), "python infra/a.py")

    def test_evidence_and_dry_run_hide_host_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = write_batch(root, ["infra/**"])
            with (
                mock.patch.object(batch, "changed_paths", return_value=["infra/tool/batch/batch.py"]),
                mock.patch.object(batch, "find_bash", return_value=self.OUTSIDE),
                mock.patch.object(batch, "run_command", return_value=(0, "", "")),
            ):
                code, out = run(
                    ["--root", str(root), "check", "--batch", "B1", "--base", "main", "--dry-run"]
                )
                self.assertEqual(code, 0)
                self.assertNotIn(str(batch.REPO_ROOT), out)

                code, _ = run(["--root", str(root), "check", "--batch", "B1", "--base", "main"])
            self.assertEqual(code, 0)
            evidence = (target / "evidence.log").read_text(encoding="utf-8")
            self.assertNotIn(self.OUTSIDE, evidence)
            self.assertNotIn(str(batch.REPO_ROOT), evidence)
            self.assertIn(f"$ {Path(self.OUTSIDE).name} .githooks/pr-body --self-test", evidence)


if __name__ == "__main__":
    unittest.main()
