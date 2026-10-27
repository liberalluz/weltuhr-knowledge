from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import skill_lint  # noqa: E402


def write_skill(root: Path, name: str, text: str) -> Path:
    path = root / ".agents" / "skills" / name / "SKILL.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


VALID = """---
name: demo
description: demo skill
---

# demo

## Owner

- Owner: tester

## 示例

```bash
echo demo
```

## 自检

python3 -B infra/tool/batch/skill_lint.py
"""


class SkillLintTests(unittest.TestCase):
    def test_valid_skill(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = write_skill(root, "demo", VALID)
            self.assertEqual(skill_lint.check_skill(path, root), [])

    def test_missing_example(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = VALID.replace("## 示例\n\n```bash\necho demo\n```\n\n", "")
            path = write_skill(root, "demo", text)
            errors = skill_lint.check_skill(path, root)
            self.assertTrue(any("示例" in error for error in errors))

    def test_name_mismatch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = write_skill(root, "other", VALID)
            errors = skill_lint.check_skill(path, root)
            self.assertTrue(any("不一致" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
