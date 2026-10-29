#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check the main-repo / external-repo boundary (ADR-0014).

Usage:
    python infra/tool/docs/check_boundary.py --root .
    python ... --external ../<project>-docs

Rules:
  - main Markdown must not link to <project>-docs/ (plain text only)
  - main must not contain records/ legal/ product/ design/ process/ business/
  - external must not contain SRS/SDD/STP/STD/SCMP copies
  - external AGENTS.md must exist when the external repo is present
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
CONTROLLED = {"srs.md", "sdd.md", "stp.md", "std.md", "scmp.md"}
EXTERNAL_DIRS = {"records", "legal", "product", "design", "process", "business"}
SKIP_DIRS = {".git", "node_modules", "build", ".dart_tool", "tmp"}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def main_links_to_external(root: Path, external_name: str) -> list[tuple[str, str, str]]:
    items: list[tuple[str, str, str]] = []
    for md in sorted(root.rglob("*.md")):
        rel = md.relative_to(root)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        for line_no, line in enumerate(read(md).splitlines(), 1):
            for raw in LINK_RE.findall(line):
                target = raw.split("#")[0]
                if external_name in target:
                    items.append(
                        ("fail", f"{rel.as_posix()}:{line_no}", f"主仓不得链外仓：{raw}")
                    )
    return items


def check_external(external: Path) -> list[tuple[str, str, str]]:
    items: list[tuple[str, str, str]] = []
    if not external.is_dir():
        return [("warn", "外仓", f"不存在：{external}")]
    if not (external / "AGENTS.md").is_file():
        items.append(("fail", "外仓 AGENTS", "缺失"))
    for path in external.rglob("*"):
        if not path.is_file():
            continue
        if path.name.lower() in CONTROLLED:
            items.append(("fail", "外仓复制受控文档", str(path.relative_to(external))))
    return items


def check_main_dirs(root: Path) -> list[tuple[str, str, str]]:
    items: list[tuple[str, str, str]] = []
    for name in sorted(EXTERNAL_DIRS):
        if (root / name).exists():
            items.append(("fail", f"主仓出现外仓目录：{name}/", "记录/法务/计划应在外仓"))
    return items


def main() -> int:
    parser = argparse.ArgumentParser(description="check main/external boundary")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--external", type=Path, default=None)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "docs").is_dir():
        print(f"not a repo root: {root}", file=sys.stderr)
        return 2
    external = args.external
    if external is None:
        candidate = root.parent / f"{root.name}-docs"
        external = candidate if candidate.is_dir() else None
    items = []
    items.extend(main_links_to_external(root, f"{root.name}-docs"))
    items.extend(check_main_dirs(root))
    if external is None:
        items.append(("warn", "外仓", "未找到兄弟 <project>-docs；CI 单仓 checkout 时允许"))
    else:
        items.extend(check_external(external.resolve()))
    if args.json:
        print(json.dumps([{"status": s, "item": i, "detail": d} for s, i, d in items], ensure_ascii=False, indent=2))
    else:
        for status, item, detail in items:
            suffix = f" — {detail}" if detail else ""
            print(f"[{status}] {item}{suffix}")
    failed = sum(1 for status, _, _ in items if status == "fail")
    print(f"\n{len(items)} 项；失败 {failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
