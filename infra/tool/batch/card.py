#!/usr/bin/env python3
"""Batch card: a small, generated YAML subset with a hash-locked approval.

The card is deliberately not a general YAML parser. It supports only the keys
and shapes this repository writes: scalars, block lists, and an ``approval``
mapping. Values are emitted as JSON strings, so quotes/colons survive a
round-trip without a PyYAML dependency.

Machine contract:

    batch, type, goal, branch, base, allowed, forbidden, acceptance,
    platforms, docs, size_budget, approval

``card_hash`` covers everything except ``approval``. Editing the card after
``batch approve`` invalidates the hash.
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

LIST_KEYS = ("allowed", "forbidden", "acceptance", "platforms", "notes", "issues", "related_prs")
SCALAR_KEYS = (
    "batch",
    "type",
    "goal",
    "branch",
    "base",
    "docs",
    "docs_impact",
    "profile",
    "milestone",
    "size_budget",
    "approval",
)


def _quote(value: Any) -> str:
    return json.dumps(str(value), ensure_ascii=False)


def _scalar(value: str) -> Any:
    text = value.strip()
    if text == "":
        return ""
    if text.startswith('"') and text.endswith('"'):
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return text[1:-1]
    if text in ("true", "false"):
        return text == "true"
    if text.lstrip("-").isdigit():
        return int(text)
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        if not inner:
            return []
        return [_scalar(part.strip()) for part in inner.split(",")]
    return text


def read_card(path: Path) -> dict[str, Any]:
    card: dict[str, Any] = {}
    current: str | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line.startswith("  - "):
            if current not in LIST_KEYS:
                raise ValueError(f"list item without a list key: {line!r}")
            card[current].append(_scalar(line[4:]))
            continue
        if line.startswith("  ") and current == "approval":
            key, _, value = stripped.partition(":")
            card["approval"][key.strip()] = _scalar(value)
            continue
        if ":" not in stripped:
            raise ValueError(f"invalid card line: {line!r}")
        key, _, value = stripped.partition(":")
        key = key.strip()
        current = key
        if key == "approval":
            card[key] = {}
        elif key in LIST_KEYS:
            parsed = _scalar(value)
            card[key] = parsed if isinstance(parsed, list) else []
        else:
            card[key] = _scalar(value)
    for key in LIST_KEYS:
        card.setdefault(key, [])
    return card


def render_card(card: dict[str, Any]) -> str:
    lines: list[str] = []
    for key in ("batch", "type", "goal", "branch", "base"):
        if key in card:
            lines.append(f"{key}: {_quote(card[key])}")
    for key in LIST_KEYS:
        lines.append(f"{key}:")
        for item in card.get(key) or []:
            lines.append(f"  - {_quote(item)}")
    for key in ("docs", "docs_impact", "profile", "milestone", "size_budget"):
        if key in card:
            value = card[key]
            lines.append(f"{key}: {value if isinstance(value, int) else _quote(value)}")
    approval = card.get("approval")
    if isinstance(approval, dict):
        lines.append("approval:")
        for key in ("by", "at", "hash"):
            if key in approval:
                lines.append(f"  {key}: {_quote(approval[key])}")
    return "\n".join(lines) + "\n"


def write_card(path: Path, card: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_card(card), encoding="utf-8")


def card_hash(card: dict[str, Any]) -> str:
    payload = {key: value for key, value in card.items() if key != "approval"}
    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def approve_card(card: dict[str, Any], by: str) -> dict[str, Any]:
    approved = {key: value for key, value in card.items() if key != "approval"}
    for key in LIST_KEYS:
        approved.setdefault(key, [])
    approved["approval"] = {
        "by": by,
        "at": datetime.now(timezone.utc).isoformat(),
        "hash": card_hash(approved),
    }
    return approved


def verify_card(card: dict[str, Any]) -> str | None:
    approval = card.get("approval")
    if not isinstance(approval, dict) or not approval.get("hash"):
        return "card 未批准：缺 approval.hash"
    if approval["hash"] != card_hash(card):
        return "card hash 不匹配：批准后卡片被改动，需要重新 batch approve"
    return None
