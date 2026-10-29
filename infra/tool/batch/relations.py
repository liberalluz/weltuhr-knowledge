"""Shared rules for the eight related classes in a PR body.

Used by `batch pr` (before create) and `.github/workflows/repo-hygiene.yml`.
Keeping one implementation is deliberate: two copies drift, and the drift is
only visible as a red CI after the PR was already created.
"""

from __future__ import annotations

import re
from typing import Iterable, Sequence

CLASSES = (
    "批次号",
    "里程碑",
    "issue",
    "PR",
    "ADR",
    "规格条",
    "用例",
    "待确认事项",
)

PR_LINK_RE = re.compile(r"\[#\d+\]\(https://github\.com/[\w.-]+/[\w.-]+/pull/\d+\)")
TODO_RE = re.compile(r"(?:^|\s)(?:#|//)\s*TODO\(confirm\):")
SPEC_RE = re.compile(r"^docs/specs/[A-Z]+-")


def _as_list(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [] if value.strip().lower() == "none" else [value.strip()]
    return [str(item).strip() for item in value if str(item).strip().lower() != "none"]


def links_from_card(card: dict) -> dict[str, object]:
    return {
        "milestone": str(card.get("milestone") or "none"),
        "issues": _as_list(card.get("issues")),
        "related_prs": _as_list(card.get("related_prs")),
    }


def required_classes(
    paths: Sequence[str],
    added_lines: Sequence[str],
    *,
    card: dict | None = None,
    pr_milestone: str | None = None,
    closing_issues: Iterable[str] = (),
) -> list[str]:
    card = card or {}
    links = links_from_card(card)
    # 批次号 is owned by the separate marker check; this function owns the
    # other seven classes. Keeping it out avoids a second, weaker batch check.
    required: set[str] = set()
    if links["milestone"] != "none" or pr_milestone:
        required.add("里程碑")
    if links["issues"] or list(closing_issues):
        required.add("issue")
    if links["related_prs"] or any(PR_LINK_RE.search(line) for line in added_lines):
        required.add("PR")
    if any(str(path).startswith("docs/decisions/") for path in paths):
        required.add("ADR")
    if any(SPEC_RE.match(str(path)) for path in paths):
        required.add("规格条")
    if any(
        str(path).startswith(("app/test/", "docs/specs/controlled/"))
        for path in paths
    ):
        required.add("用例")
    if any(TODO_RE.search(line) for line in added_lines):
        required.add("待确认事项")
    return [name for name in CLASSES if name in required]


def body_entries(body: str) -> dict[str, list[str]]:
    entries: dict[str, list[str]] = {}
    inside = False
    for line in body.splitlines():
        if line.strip() == "## 关联":
            inside = True
            continue
        if inside and line.startswith("## "):
            break
        if not inside:
            continue
        match = re.match(r"^- ([^：]+)：(.*)$", line.strip())
        if not match:
            continue
        key = match.group(1).strip()
        if key in CLASSES:
            entries.setdefault(key, []).append(match.group(2).strip())
    return entries


def missing_classes(body: str, required: Sequence[str]) -> list[str]:
    entries = body_entries(body)
    return [name for name in required if name not in entries]
