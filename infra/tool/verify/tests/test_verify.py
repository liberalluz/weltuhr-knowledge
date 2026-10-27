from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "batch"))

import card  # noqa: E402
import check  # noqa: E402
import verify  # noqa: E402


def write_batch(root: Path, *, evidence: bool = True):
    target = root / "B1"
    target.mkdir(parents=True, exist_ok=True)
    (target / "state.json").write_text(
        json.dumps(
            {
                "batch": "B1",
                "type": "process",
                "branch": "process/B1",
                "base": "main",
            }
        ),
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
        },
        "tester",
    )
    (target / "scope.json").write_text(json.dumps(scope), encoding="utf-8")
    if evidence:
        (target / "evidence.log").write_text("RESULT: PASS\n", encoding="utf-8")
    (target / "pr-body.md").write_text(
        "- **未验**：真实三端构建\n", encoding="utf-8"
    )
    return target


class VerifyTests(unittest.TestCase):
    def test_pass_and_unverified(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = write_batch(Path(tmp))
            report = verify.collect(target, paths_override=["infra/a.py"])
            self.assertEqual(report["verdict"], "NEEDS HUMAN")
            self.assertTrue(any("真实三端构建" in item for item in report["unverified"]))

    def test_clean_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = write_batch(Path(tmp))
            (target / "pr-body.md").unlink()
            report = verify.collect(target, paths_override=["infra/a.py"])
            self.assertEqual(report["verdict"], "PASS")

    def test_scope_violation_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = write_batch(Path(tmp))
            report = verify.collect(target, paths_override=["app/lib/a.dart"])
            self.assertEqual(report["verdict"], "FAIL")
            self.assertTrue(report["violations"])

    def test_missing_evidence_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = write_batch(Path(tmp), evidence=False)
            report = verify.collect(target, paths_override=["infra/a.py"])
            self.assertEqual(report["verdict"], "FAIL")
            self.assertFalse(report["evidenceOk"])

    def test_render_has_sections(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = write_batch(Path(tmp))
            report = verify.collect(target, paths_override=["infra/a.py"])
            text = verify.render(report)
            for section in ("## Claim", "## Scope", "## Evidence", "## Unverified", "## Verdict"):
                self.assertIn(section, text)


if __name__ == "__main__":
    unittest.main()
