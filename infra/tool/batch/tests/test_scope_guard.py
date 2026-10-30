from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check  # noqa: E402


def make_scope(**overrides):
    scope = {
        "batch": "M2",
        "type": "process",
        "allowed": ["infra/tool/batch/**", ".githooks/pre-push"],
        "forbidden": [],
    }
    scope.update(overrides)
    return check.sign_scope(scope, "tester")


class GlobTests(unittest.TestCase):
    def test_directory_glob(self):
        self.assertTrue(check.matches_any("app/lib/a.dart", ["app/lib/**"]))
        self.assertTrue(check.matches_any("app/lib/sub/a.dart", ["app/lib/**"]))
        self.assertFalse(check.matches_any("app/src/a.dart", ["app/lib/**"]))

    def test_recursive_python_glob(self):
        self.assertTrue(check.matches_any("infra/tool/batch/check.py", ["**/*.py"]))
        self.assertTrue(check.matches_any("check.py", ["**/*.py"]))

    def test_literal_directory_matches_descendants(self):
        self.assertTrue(
            check.matches_any("app/lib/core/tree/pack_coverage.dart", ["app/lib/core/tree"])
        )
        self.assertTrue(
            check.matches_any("app/lib/core/tree/sub/a.dart", ["app/lib/core/tree/"])
        )
        self.assertFalse(
            check.matches_any("app/lib/core/treehouse/a.dart", ["app/lib/core/tree"])
        )

    def test_literal_file_still_matches_exactly(self):
        self.assertTrue(
            check.matches_any(".githooks/pre-push", [".githooks/pre-push"])
        )


class CheckTests(unittest.TestCase):
    def test_in_scope_passes(self):
        scope = make_scope()
        self.assertEqual(check.check_paths(["infra/tool/batch/check.py"], scope), [])

    def test_out_of_scope_blocks(self):
        scope = make_scope()
        violations = check.check_paths(["app/lib/foo.dart"], scope)
        self.assertTrue(any("不在 allowed" in item for item in violations))

    def test_feature_batch_cannot_touch_process_file(self):
        scope = make_scope(
            type="feat",
            allowed=["app/lib/**", ".githooks/pre-push"],
        )
        violations = check.check_paths([".githooks/pre-push"], scope)
        self.assertTrue(any("forbidden/流程文件" in item for item in violations))

    def test_process_batch_can_touch_process_file(self):
        scope = make_scope(type="process", allowed=[".githooks/**"])
        self.assertEqual(check.check_paths([".githooks/pre-push"], scope), [])

    def test_explicit_forbidden_wins(self):
        scope = make_scope(allowed=["app/**"], forbidden=["app/secret/**"])
        violations = check.check_paths(["app/secret/key.dart"], scope)
        self.assertTrue(any("forbidden" in item for item in violations))


class HashTests(unittest.TestCase):
    def test_signed_scope_verifies(self):
        self.assertIsNone(check.verify_scope(make_scope()))

    def test_edit_invalidates_hash(self):
        scope = make_scope()
        scope["allowed"].append("app/lib/rogue.dart")
        self.assertIn("hash 不匹配", check.verify_scope(scope) or "")

    def test_missing_approval_blocks(self):
        scope = make_scope()
        scope.pop("approval")
        self.assertIn("未批准", check.verify_scope(scope) or "")


class AddPathTests(unittest.TestCase):
    def test_add_path_requires_reason(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "scope.json"
            path.write_text(json.dumps(make_scope(), ensure_ascii=False), encoding="utf-8")
            with self.assertRaises(RuntimeError):
                check.add_path(path, "app/lib/new.dart", "", "tester")

    def test_add_path_updates_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "scope.json"
            path.write_text(json.dumps(make_scope(), ensure_ascii=False), encoding="utf-8")
            signed = check.add_path(path, "app/lib/new.dart", "needed", "tester")
            self.assertIn("app/lib/new.dart", signed["allowed"])
            self.assertIsNone(check.verify_scope(check.load_scope(path)))

    def test_cli_add_requires_yes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "scope.json"
            path.write_text(json.dumps(make_scope(), ensure_ascii=False), encoding="utf-8")
            self.assertEqual(
                check.main(["--scope", str(path), "--add", "app/lib/new.dart", "--reason", "needed"]),
                2,
            )


if __name__ == "__main__":
    unittest.main()
