#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Read-only docs checks not covered by `tool/docs/check.dart`:

  baseline  validate docs/baselines.md (6 columns, BL-x monotonic, dates/anchors)
  budget    compare controlled docs against infra/tool/docs/budgets.json

Usage:
    python infra/tool/docs/audit.py [baseline|budget|all] [--root <repo>]
Exit: 0 pass · 1 violation · 2 argument/path error.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

BL_RE = re.compile(r"^BL-(\d+)$")
SHA_RE = re.compile(r"^[0-9a-f]{7,40}$")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
COLUMNS = ["标识", "锚点提交", "冻结日期", "范围（配置项类别）", "明细", "已知缺口"]


def parse_table(text: str, prefix: str = "| 标识 |") -> tuple[list[str], list[list[str]]]:
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.strip().startswith(prefix)), None)
    if start is None:
        return [], []
    header = [cell.strip() for cell in lines[start].strip().strip("|").split("|")]
    rows: list[list[str]] = []
    for line in lines[start + 1:]:
        stripped = line.strip()
        if not stripped.startswith("|"):
            break
        if set(stripped) <= {"|", "-", ":", " "}:
            continue
        rows.append([cell.strip() for cell in stripped.strip("|").split("|")])
    return header, rows


def check_baseline(root: Path) -> list[str]:
    errors: list[str] = []
    path = root / "docs" / "baselines.md"
    if not path.is_file():
        return ["docs/baselines.md 不存在"]
    header, rows = parse_table(path.read_text(encoding="utf-8", errors="replace"))
    if header != COLUMNS:
        errors.append("基线表头不符：" + " | ".join(header))
    seen: set[int] = set()
    last = -1
    for i, row in enumerate(rows, 1):
        if len(row) < 6:
            errors.append(f"第 {i} 行列数不足")
            continue
        ident = row[0].strip("` ")
        match = BL_RE.match(ident)
        if not match:
            errors.append(f"第 {i} 行标识非法：{row[0]}")
            continue
        number = int(match.group(1))
        if number in seen:
            errors.append(f"{ident} 重复")
        if number <= last:
            errors.append(f"{ident} 未单调递增")
        seen.add(number)
        last = number
        anchor = row[1].strip("` ")
        if anchor != "未登记" and not SHA_RE.match(anchor):
            errors.append(f"{ident} 锚点不是 sha/未登记：{row[1]}")
        try:
            date.fromisoformat(row[2])
        except ValueError:
            errors.append(f"{ident} 冻结日期非法：{row[2]}")
        for target in LINK_RE.findall(row[4]):
            if target.startswith(("http://", "https://", "#")):
                continue
            resolved = (path.parent / target.split("#")[0]).resolve()
            if not resolved.exists():
                errors.append(f"{ident} 明细链接不存在：{target}")
    return errors


def check_budget(root: Path) -> list[str]:
    config_path = root / "infra" / "tool" / "docs" / "budgets.json"
    if not config_path.is_file():
        return ["infra/tool/docs/budgets.json 不存在"]
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"budgets.json 不可读：{exc}"]
    limits = config.get("limits")
    if not isinstance(limits, dict) or not limits:
        return ["budgets.json 缺 limits"]
    errors: list[str] = []
    for name, limit in limits.items():
        if not isinstance(limit, int) or limit <= 0:
            errors.append(f"{name}: limit 非正整数")
            continue
        path = root / name
        if not path.is_file():
            errors.append(f"{name}: 文件不存在")
            continue
        size = path.stat().st_size
        if size > limit:
            errors.append(f"{name}: {size} B > {limit} B")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="docs baseline/budget audit")
    parser.add_argument("command", nargs="?", choices=("baseline", "budget", "all"), default="all")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "docs").is_dir():
        print(f"not a repo root: {root}", file=sys.stderr)
        return 2
    errors: list[str] = []
    if args.command in ("baseline", "all"):
        errors.extend(check_baseline(root))
    if args.command in ("budget", "all"):
        errors.extend(check_budget(root))
    if errors:
        for item in errors:
            print(f"[fail] {item}")
        print(f"\n{len(errors)} 项失败")
        return 1
    print("[ok] docs baseline")
    print("[ok] docs budget")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
