#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check that rule changes are discoverable from AGENTS entry points.

Usage:
    python infra/tool/docs/check_entrypoints.py --root .
    python ... --external ../<project>-docs
    python ... --diff-base origin/main   # optional rule-change sync gate

Static checks:
  - root/module AGENTS exist
  - root AGENTS points at docs/AGENTS, git-conventions, batch skill
  - root/infra/docs AGENTS mention the new batch/docs rules
  - external AGENTS (if present) states live/frozen/SDP boundaries
  - commands referenced by AGENTS resolve to existing files

Diff check (opt-in):
  - if a rule file changed but no AGENTS file changed -> fail
    (pass --allow-entry-noop to record an explicit exception)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

MODULE_AGENTS = [
    "AGENTS.md",
    "app/AGENTS.md",
    "server/AGENTS.md",
    "content/AGENTS.md",
    "infra/AGENTS.md",
    "docs/AGENTS.md",
]

ROOT_MARKERS = [
    "docs/AGENTS.md",
    "docs/specs/git-conventions.md",
    ".agents/skills/batch/SKILL.md",
    "changelog.d",
    "records/live",
    "docs-impact",
    "profile",
    "size_budget",
    "relations.py",
]

MODULE_MARKERS = {
    "infra/AGENTS.md": [
        "docs-impact",
        "profile",
        "size_budget",
        "changelog",
        "relations.py",
        "audit.py",
    ],
    "docs/AGENTS.md": ["changelog.d", "tool/docs/check.dart", "audit.py"],
}

RULE_FILES = {
    "AGENTS.md",
    "docs/AGENTS.md",
    "infra/AGENTS.md",
    "docs/specs/git-conventions.md",
    ".githooks/commit-msg",
    ".githooks/pr-body",
    ".agents/skills/batch/SKILL.md",
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def check_static(root: Path, external: Path | None) -> list[tuple[str, str, str]]:
    items: list[tuple[str, str, str]] = []
    for rel in MODULE_AGENTS:
        path = root / rel
        if not path.is_file():
            items.append(("fail", f"{rel}: 缺失", "新 agent 没有模块入口"))
            continue
        text = read(path)
        markers = ROOT_MARKERS if rel == "AGENTS.md" else MODULE_MARKERS.get(rel, [])
        missing = [marker for marker in markers if marker not in text]
        if missing:
            items.append(("fail", f"{rel}: 缺关键规则", "、".join(missing)))
        else:
            items.append(("ok", rel, "入口存在且包含关键规则"))

    for rel in (
        "docs/AGENTS.md",
        "docs/specs/git-conventions.md",
        ".agents/skills/batch/SKILL.md",
        "infra/tool/batch/relations.py",
        "infra/tool/docs/audit.py",
    ):
        if not (root / rel).is_file():
            items.append(("fail", f"{rel}: 引用的文件不存在", "AGENTS 指向了不存在的规则"))

    if external is None:
        candidate = root.parent / f"{root.name}-docs"
        external = candidate if candidate.is_dir() else None
    if external is None:
        items.append(("warn", "外仓 AGENTS", "未找到兄弟 <project>-docs；CI 单仓 checkout 时允许"))
    else:
        path = external / "AGENTS.md"
        if not path.is_file():
            items.append(("fail", "外仓 AGENTS 缺失", str(path)))
        else:
            text = read(path)
            missing = [m for m in ("records/live", "冻结", "SDP", "不复制") if m not in text]
            if missing:
                items.append(("fail", "外仓 AGENTS 缺边界", "、".join(missing)))
            else:
                items.append(("ok", "外仓 AGENTS", "live/frozen、SDP、不复制已登记"))
    return items


def check_diff(root: Path, base: str, allow_noop: bool) -> list[tuple[str, str, str]]:
    proc = subprocess.run(
        ["git", "-C", str(root), "diff", "--name-only", f"{base}...HEAD"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return [("warn", "规则变更同步", f"无法读取 {base} 的 diff，跳过")]
    changed = set(proc.stdout.splitlines())
    rules = changed & RULE_FILES
    if not rules:
        return [("ok", "规则变更同步", "本批未改规则文件")]
    if allow_noop:
        return [("warn", "规则变更同步", "已声明 entry-noop；确认不是漏改")]
    if not (changed & set(MODULE_AGENTS)):
        return [
            (
                "fail",
                "规则变更但入口未动",
                "改了 " + "、".join(sorted(rules)) + "；AGENTS 未同步",
            )
        ]
    return [("ok", "规则变更同步", "规则与入口同批更新")]


def main() -> int:
    parser = argparse.ArgumentParser(description="check AGENTS entry points")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--external", type=Path, default=None)
    parser.add_argument("--diff-base", default=None)
    parser.add_argument("--allow-entry-noop", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "AGENTS.md").is_file():
        print(f"not a repo root: {root}", file=sys.stderr)
        return 2
    items = check_static(root, args.external)
    if args.diff_base:
        items.extend(check_diff(root, args.diff_base, args.allow_entry_noop))
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
