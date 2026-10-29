from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_boundary as cb  # noqa: E402


def make_root() -> Path:
    root = Path(tempfile.mkdtemp())
    (root / "docs").mkdir()
    (root / "docs" / "README.md").write_text(
        "开发计划：`weltuhr-knowledge-docs/process/sdp.md`（仓外）\n",
        encoding="utf-8",
    )
    return root


class BoundaryTests(unittest.TestCase):
    def test_plain_text_passes(self):
        root = make_root()
        self.assertEqual(cb.main_links_to_external(root, "weltuhr-knowledge-docs"), [])

    def test_markdown_link_to_external_fails(self):
        root = make_root()
        (root / "docs" / "README.md").write_text(
            "[计划](../weltuhr-knowledge-docs/process/sdp.md)\n", encoding="utf-8"
        )
        items = cb.main_links_to_external(root, "weltuhr-knowledge-docs")
        self.assertTrue(any(status == "fail" for status, _, _ in items))

    def test_external_controlled_copy_fails(self):
        external = Path(tempfile.mkdtemp())
        (external / "AGENTS.md").write_text("agent", encoding="utf-8")
        (external / "docs").mkdir()
        (external / "docs" / "srs.md").write_text("copy", encoding="utf-8")
        items = cb.check_external(external)
        self.assertTrue(any(status == "fail" and "受控" in item for status, item, _ in items))

    def test_main_records_dir_fails(self):
        root = make_root()
        (root / "records").mkdir()
        items = cb.check_main_dirs(root)
        self.assertTrue(any(status == "fail" for status, _, _ in items))


if __name__ == "__main__":
    unittest.main()
