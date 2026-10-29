from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_entrypoints as ce  # noqa: E402


def make_root() -> Path:
    root = Path(tempfile.mkdtemp())
    (root / "docs/specs").mkdir(parents=True)
    (root / "docs/AGENTS.md").write_text(
        "changelog.d tool/docs/check.dart audit.py", encoding="utf-8"
    )
    (root / "docs/specs/git-conventions.md").write_text("rules", encoding="utf-8")
    (root / "infra/tool/batch").mkdir(parents=True)
    (root / "infra/tool/batch/relations.py").write_text("", encoding="utf-8")
    (root / "infra/tool/docs").mkdir(parents=True)
    (root / "infra/tool/docs/audit.py").write_text("", encoding="utf-8")
    (root / ".agents/skills/batch").mkdir(parents=True)
    (root / ".agents/skills/batch/SKILL.md").write_text("skill", encoding="utf-8")
    (root / "AGENTS.md").write_text(
        " ".join(ce.ROOT_MARKERS), encoding="utf-8"
    )
    for rel in ("app/AGENTS.md", "server/AGENTS.md", "content/AGENTS.md"):
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_text("module", encoding="utf-8")
    (root / "infra/AGENTS.md").write_text(
        " ".join(ce.MODULE_MARKERS["infra/AGENTS.md"]), encoding="utf-8"
    )
    (root / "docs/AGENTS.md").write_text(
        " ".join(ce.MODULE_MARKERS["docs/AGENTS.md"]), encoding="utf-8"
    )
    return root


class EntrypointTests(unittest.TestCase):
    def test_static_pass(self):
        root = make_root()
        items = ce.check_static(root, None)
        self.assertFalse([item for item in items if item[0] == "fail"])

    def test_missing_root_marker_fails(self):
        root = make_root()
        (root / "AGENTS.md").write_text("docs/AGENTS.md", encoding="utf-8")
        items = ce.check_static(root, None)
        self.assertTrue(any(status == "fail" and "AGENTS.md" in item for status, item, _ in items))

    def test_missing_external_agents_fails_when_given(self):
        root = make_root()
        external = Path(tempfile.mkdtemp())
        items = ce.check_static(root, external)
        self.assertTrue(any(status == "fail" and "外仓" in item for status, item, _ in items))

    def _diff(self, files: list[str], allow_noop: bool = False):
        root = make_root()
        fake = mock.Mock(returncode=0, stdout="\n".join(files), stderr="")
        with mock.patch.object(ce.subprocess, "run", return_value=fake):
            return ce.check_diff(root, "origin/main", allow_noop)

    def test_rule_change_without_agents_fails(self):
        items = self._diff(["docs/specs/git-conventions.md"])
        self.assertTrue(any(status == "fail" for status, _, _ in items))

    def test_rule_change_with_agents_passes(self):
        items = self._diff(["docs/specs/git-conventions.md", "AGENTS.md"])
        self.assertTrue(any(status == "ok" for status, _, _ in items))

    def test_non_rule_change_does_not_trigger(self):
        items = self._diff(["app/lib/x.dart"])
        self.assertTrue(any(status == "ok" and "未改规则" in detail for status, _, detail in items))


if __name__ == "__main__":
    unittest.main()
