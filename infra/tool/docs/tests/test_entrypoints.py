from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
