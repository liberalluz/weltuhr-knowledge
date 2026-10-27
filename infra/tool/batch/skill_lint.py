#!/usr/bin/env python3
"""C5 skill lint: frontmatter + owner/example/self-check sections."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SKILLS = ROOT / ".agents" / "skills"
REQUIRED = ("## Owner", "## 示例", "## 自检")
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def parse_frontmatter(text: str) -> tuple[dict[str, str], str | None]:
    if not text.startswith("---\n"):
        return {}, "缺少 frontmatter 起始 ---"
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, "缺少 frontmatter 结束 ---"
    fields: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if line.startswith((" ", "\t")) or not line.strip():
            continue
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip().strip('"').strip("'")
    return fields, None


def check_skill(path: Path, root: Path) -> list[str]:
    errors: list[str] = []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [f"读取失败：{exc}"]
    fields, fm_error = parse_frontmatter(text)
    if fm_error:
        errors.append(fm_error)
    name = fields.get("name", "")
    description = fields.get("description", "")
    if not name:
        errors.append("frontmatter 缺 name")
    elif not NAME_RE.match(name):
        errors.append(f"name 不是 kebab-case：{name}")
    if path.parent.name != name:
        errors.append(f"name {name!r} 与目录 {path.parent.name!r} 不一致")
    if not description:
        errors.append("frontmatter 缺 description")
    for section in REQUIRED:
        if section not in text:
            errors.append(f"缺节：{section}")
    owner = re.search(r"^## Owner\s*\n+(.*)$", text, re.M)
    if owner:
        body = owner.group(1).strip()
        if not body or body.startswith("## "):
            errors.append("Owner 节为空")
    if "## 示例" in text and "```" not in text.split("## 示例", 1)[1]:
        errors.append("示例节没有代码块")
    if "## 自检" in text and "skill_lint.py" not in text.split("## 自检", 1)[1]:
        errors.append("自检节没有 skill_lint.py 命令")
    rel = path.relative_to(root).as_posix()
    for bad in ("\r", "\t"):
        if bad in text:
            errors.append(f"{rel} 含非法控制字符")
    return errors


def collect(root: Path) -> list[Path]:
    skills = root / ".agents" / "skills"
    if not skills.is_dir():
        return []
    return sorted(skills.glob("*/SKILL.md"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lint project skills")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    root = args.root if args.root.is_absolute() else ROOT / args.root
    paths = collect(root)
    if not paths:
        print(f"no skills under {root / '.agents' / 'skills'}", file=sys.stderr)
        return 1
    rows: list[dict[str, object]] = []
    failed = 0
    for path in paths:
        errors = check_skill(path, root)
        rows.append({"path": path.as_posix(), "ok": not errors, "errors": errors})
        failed += bool(errors)
        if errors and not args.json:
            print(f"[FAIL] {path}")
            for error in errors:
                print(f"  - {error}")
        elif not args.json:
            print(f"[ok] {path}")
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    print(f"skill_lint: {len(paths) - failed}/{len(paths)} ok")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
