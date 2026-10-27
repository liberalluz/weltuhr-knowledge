#!/usr/bin/env python3
"""C13 read-only verifier: restate scope, evidence and unverified items.

This tool never writes. It reads `.batch/<id>/` and the current diff, then prints
a report a reviewer can compare with the PR body. A missing or invalid input is
a FAIL, not a silent pass.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Sequence

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "infra" / "tool" / "batch"))
import batch  # noqa: E402
import card  # noqa: E402
import check  # noqa: E402


def load_json(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def unverified_lines(text: str | None) -> list[str]:
    if not text:
        return []
    out: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if "未验" in stripped and stripped.startswith(("- ", "* ")) and stripped not in out:
            out.append(stripped.lstrip("-* "))
    return out


def collect(
    batch_dir: Path,
    *,
    paths_override: Sequence[str] | None = None,
    base_override: str | None = None,
) -> dict[str, Any]:
    state = load_json(batch_dir / "state.json") or {}
    card_data, card_error = batch.read_card_safe(batch_dir)
    scope = load_json(batch_dir / "scope.json")
    merge = load_json(batch_dir / "merge.json")
    evidence_path = batch_dir / "evidence.log"
    evidence_text = (
        evidence_path.read_text(encoding="utf-8") if evidence_path.exists() else ""
    )
    pr_body_path = batch_dir / "pr-body.md"
    pr_body_text = (
        pr_body_path.read_text(encoding="utf-8") if pr_body_path.exists() else ""
    )

    card_approval = card.verify_card(card_data) if card_data is not None else None
    scope_approval = check.verify_scope(scope) if scope is not None else None
    base = base_override or state.get("base") or (card_data or {}).get("base") or "origin/main"
    paths = (
        list(paths_override)
        if paths_override is not None
        else batch.changed_paths(str(base))
    )
    violations = check.check_paths(paths, scope) if scope is not None else []
    evidence_ok = "RESULT: PASS" in evidence_text
    unverified = unverified_lines(pr_body_text) + unverified_lines(evidence_text)
    # preserve order, drop duplicates
    unverified = list(dict.fromkeys(unverified))

    failures: list[str] = []
    if card_data is None:
        failures.append(f"card 缺失或无法解析：{card_error or 'no card.yaml'}")
    elif card_approval:
        failures.append(card_approval)
    if scope is None:
        failures.append("scope.json 缺失")
    elif scope_approval:
        failures.append(scope_approval)
    if not evidence_ok:
        failures.append("evidence.log 缺失或没有 RESULT: PASS")
    failures.extend(violations)

    if failures:
        verdict = "FAIL"
    elif unverified:
        verdict = "NEEDS HUMAN"
    else:
        verdict = "PASS"

    return {
        "batch": (card_data or {}).get("batch") or state.get("batch") or batch_dir.name,
        "goal": (card_data or {}).get("goal"),
        "acceptance": (card_data or {}).get("acceptance") or [],
        "branch": state.get("branch") or (card_data or {}).get("branch"),
        "base": base,
        "paths": paths,
        "cardApproval": card_approval,
        "scopeApproval": scope_approval,
        "scopeAllowed": len((scope or {}).get("allowed") or []),
        "scopeForbidden": len((scope or {}).get("forbidden") or []),
        "evidenceOk": evidence_ok,
        "evidencePath": str(evidence_path) if evidence_path.exists() else None,
        "evidenceResult": next(
            (line.strip() for line in evidence_text.splitlines() if line.strip().startswith("RESULT:")),
            None,
        ),
        "violations": violations,
        "unverified": unverified,
        "merged": merge,
        "failures": failures,
        "verdict": verdict,
    }


def render(report: dict[str, Any]) -> str:
    lines = [
        f"# Verifier — {report['batch']}",
        "",
        "## Claim",
        "",
        f"- Goal: {report.get('goal') or '(missing)'}",
        f"- Branch: {report.get('branch') or '(unknown)'}",
        f"- Base: {report.get('base')}",
    ]
    for item in report.get("acceptance") or []:
        lines.append(f"- Acceptance: {item}")
    lines.extend(
        [
            "",
            "## Scope",
            "",
            f"- Changed: {len(report['paths'])} paths",
            f"- Card approval: {'OK' if not report['cardApproval'] else report['cardApproval']}",
            f"- Scope approval: {'OK' if not report['scopeApproval'] else report['scopeApproval']}",
            f"- Allowed / forbidden: {report['scopeAllowed']} / {report['scopeForbidden']}",
        ]
    )
    if report["violations"]:
        lines.append("- Violations:")
        lines.extend(f"  - {item}" for item in report["violations"])
    else:
        lines.append("- Violations: none")

    lines.extend(
        [
            "",
            "## Evidence",
            "",
            f"- evidence.log: {'PASS' if report['evidenceOk'] else 'MISSING/FAIL'}",
            f"- Result: {report.get('evidenceResult') or '(none)'}",
            f"- Path: {report.get('evidencePath') or '(none)'}",
        ]
    )
    if report.get("merged"):
        lines.append(f"- Merged: PR #{report['merged'].get('pr')} {report['merged'].get('sha') or ''}")

    lines.extend(["", "## Unverified", ""])
    lines.extend(
        report["unverified"]
        or ["- (none stated in pr-body.md / evidence.log — verify that is actually true)"]
    )

    lines.extend(["", "## Verdict", "", f"**{report['verdict']}**"])
    if report["failures"]:
        lines.extend(["", "Blockers:"])
        lines.extend(f"- {item}" for item in report["failures"])
    return "\n".join(lines) + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Read-only batch verifier")
    parser.add_argument("--root", type=Path, default=batch.DEFAULT_ROOT)
    parser.add_argument("--batch")
    parser.add_argument("--base")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    root = args.root if args.root.is_absolute() else REPO_ROOT / args.root
    batch_dir = batch.resolve_batch(root, args.batch)
    if batch_dir is None:
        print(f"no batch found under {root}", file=sys.stderr)
        return 2
    report = collect(batch_dir, base_override=args.base)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render(report), end="")
    return 0 if report["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
