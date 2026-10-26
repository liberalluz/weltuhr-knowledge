#!/usr/bin/env python3
"""Merge gate for weltuhr-knowledge pull requests.

The gate is intentionally conservative: it refuses to merge unless the PR is
open, not a draft, conflict-free, every check has a successful/neutral/skipped
conclusion, and no review is requesting changes. The actual merge only happens
when ``--yes`` is passed; every successful merge is appended to
``.batch/merge-log.jsonl``.

Usage (from the repository root):

    python3 infra/tool/batch/merge.py --pr 190 --dry-run
    python3 infra/tool/batch/merge.py --pr 190 --yes

Exit codes:
    0  eligible / merged / dry-run says eligible
    1  blocked by a gate
    2  eligible but --yes was not passed
    3  gh or repository error
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_LOG = REPO_ROOT / ".batch" / "merge-log.jsonl"

ALLOWED_CONCLUSIONS = {"success", "neutral", "skipped"}
FAILED_CONCLUSIONS = {
    "failure",
    "timed_out",
    "cancelled",
    "action_required",
    "startup_failure",
    "error",
}
PENDING_CONCLUSIONS = {
    "pending",
    "expected",
    "queued",
    "in_progress",
    "waiting",
    "requested",
}
ALLOWED_MERGE_STATES = {"CLEAN", "HAS_HOOKS"}
FIELDS = (
    "number,url,title,state,isDraft,mergeable,mergeStateStatus,"
    "reviewDecision,statusCheckRollup"
)


@dataclass(frozen=True)
class Check:
    name: str
    status: str
    conclusion: str
    url: str = ""


@dataclass
class Verdict:
    pr: dict[str, Any]
    checks: list[Check] = field(default_factory=list)
    blockers: list[str] = field(default_factory=list)
    passed: int = 0
    failed: int = 0
    pending: int = 0

    @property
    def eligible(self) -> bool:
        return not self.blockers


def normalize_check(raw: dict[str, Any]) -> Check | None:
    """Normalize a CheckRun or StatusContext from statusCheckRollup."""
    if not isinstance(raw, dict):
        return None
    if raw.get("state"):
        # StatusContext: SUCCESS / FAILURE / PENDING / ERROR / EXPECTED
        return Check(
            name=str(raw.get("context") or raw.get("name") or "(unnamed)"),
            status="completed",
            conclusion=str(raw["state"]).lower(),
            url=str(raw.get("targetUrl") or ""),
        )
    return Check(
        name=str(raw.get("name") or raw.get("context") or "(unnamed)"),
        status=str(raw.get("status") or "").lower(),
        conclusion=str(raw.get("conclusion") or "").lower(),
        url=str(raw.get("detailsUrl") or ""),
    )


def evaluate(pr: dict[str, Any]) -> Verdict:
    """Apply the merge gate to a `gh pr view --json` payload."""
    checks = [
        check
        for raw in (pr.get("statusCheckRollup") or [])
        if (check := normalize_check(raw)) is not None
    ]
    verdict = Verdict(pr=pr, checks=checks)

    if str(pr.get("state") or "").upper() != "OPEN":
        verdict.blockers.append(f"PR 状态为 {pr.get('state')!r}，不是 OPEN")
    if pr.get("isDraft"):
        verdict.blockers.append("PR 仍是 draft")
    if str(pr.get("mergeable") or "").upper() != "MERGEABLE":
        verdict.blockers.append(f"mergeable={pr.get('mergeable')!r}，不是 MERGEABLE")
    merge_state = str(pr.get("mergeStateStatus") or "").upper()
    if merge_state not in ALLOWED_MERGE_STATES:
        verdict.blockers.append(
            f"mergeStateStatus={merge_state or 'UNKNOWN'}，不是 CLEAN/HAS_HOOKS"
        )
    review = str(pr.get("reviewDecision") or "").upper()
    if review == "CHANGES_REQUESTED":
        verdict.blockers.append("评审状态为 CHANGES_REQUESTED")
    if review == "REVIEW_REQUIRED":
        verdict.blockers.append("缺少必需的评审批准")

    if not checks:
        verdict.blockers.append("PR 上没有任何检查")

    for check in checks:
        if check.status != "completed":
            verdict.pending += 1
        elif check.conclusion in FAILED_CONCLUSIONS:
            verdict.failed += 1
        elif check.conclusion in PENDING_CONCLUSIONS or check.conclusion == "":
            verdict.pending += 1
        elif check.conclusion in ALLOWED_CONCLUSIONS:
            verdict.passed += 1
        else:
            # Unknown conclusions are treated as failures on purpose.
            verdict.failed += 1

    if verdict.failed:
        names = ", ".join(c.name for c in checks if c.conclusion in FAILED_CONCLUSIONS)
        verdict.blockers.append(f"{verdict.failed} 个检查失败" + (f"：{names}" if names else ""))
    if verdict.pending:
        names = ", ".join(
            c.name
            for c in checks
            if c.status != "completed"
            or c.conclusion in PENDING_CONCLUSIONS
            or c.conclusion == ""
        )
        verdict.blockers.append(
            f"{verdict.pending} 个检查仍未完成" + (f"：{names}" if names else "")
        )
    return verdict


def run_gh(args: Sequence[str]) -> tuple[int, str, str]:
    """Run gh, using temp files instead of pipes for sandbox compatibility."""
    gh = shutil.which("gh")
    if gh is None:
        raise RuntimeError("gh not found in PATH")
    with tempfile.TemporaryDirectory(prefix="batch-gh-") as tmp:
        out_path = Path(tmp) / "stdout"
        err_path = Path(tmp) / "stderr"
        with out_path.open("w", encoding="utf-8") as out, err_path.open(
            "w", encoding="utf-8"
        ) as err:
            proc = subprocess.run(
                [gh, *args],
                cwd=REPO_ROOT,
                stdout=out,
                stderr=err,
                text=True,
            )
        return (
            proc.returncode,
            out_path.read_text(encoding="utf-8", errors="replace").strip(),
            err_path.read_text(encoding="utf-8", errors="replace").strip(),
        )


def fetch_pr(number: int, repo: str | None) -> dict[str, Any]:
    args = ["pr", "view", str(number), "--json", FIELDS]
    if repo:
        args.extend(["--repo", repo])
    code, out, err = run_gh(args)
    if code != 0:
        raise RuntimeError(err or out or f"gh pr view exited {code}")
    try:
        return json.loads(out)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"cannot parse gh pr view output: {exc}") from exc


def merge_pr(number: int, repo: str | None) -> None:
    args = ["pr", "merge", str(number), "--squash", "--delete-branch"]
    if repo:
        args.extend(["--repo", repo])
    code, out, err = run_gh(args)
    if code != 0:
        raise RuntimeError(err or out or f"gh pr merge exited {code}")


def log_merge(verdict: Verdict, log_path: Path, repo: str | None) -> None:
    pr = verdict.pr
    record = {
        "at": datetime.now(timezone.utc).isoformat(),
        "repo": repo or "",
        "pr": pr.get("number"),
        "url": pr.get("url"),
        "title": pr.get("title"),
        "operator": os.environ.get("GITHUB_ACTOR") or getpass.getuser(),
        "mergeStateStatus": pr.get("mergeStateStatus"),
        "reviewDecision": pr.get("reviewDecision"),
        "checks": {
            "total": len(verdict.checks),
            "passed": verdict.passed,
            "failed": verdict.failed,
            "pending": verdict.pending,
        },
    }
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def render(verdict: Verdict) -> str:
    pr = verdict.pr
    lines = [
        f"PR #{pr.get('number')} {pr.get('url') or ''}".rstrip(),
        f"Title: {pr.get('title') or ''}",
        (
            "State: "
            f"{pr.get('state')}  draft={bool(pr.get('isDraft'))}  "
            f"mergeable={pr.get('mergeable')}  "
            f"mergeState={pr.get('mergeStateStatus')}  "
            f"review={pr.get('reviewDecision') or 'none'}"
        ),
        (
            f"Checks: {verdict.passed} passed / {verdict.failed} failed / "
            f"{verdict.pending} pending (of {len(verdict.checks)})"
        ),
    ]
    if verdict.blockers:
        lines.append("Blockers:")
        lines.extend(f"- {blocker}" for blocker in verdict.blockers)
        lines.append("Verdict: BLOCKED")
    else:
        lines.append("Verdict: READY")
    return "\n".join(lines)


def _json_payload(verdict: Verdict) -> dict[str, Any]:
    return {
        "pr": {
            "number": verdict.pr.get("number"),
            "url": verdict.pr.get("url"),
            "title": verdict.pr.get("title"),
            "state": verdict.pr.get("state"),
            "draft": bool(verdict.pr.get("isDraft")),
            "mergeable": verdict.pr.get("mergeable"),
            "mergeStateStatus": verdict.pr.get("mergeStateStatus"),
            "reviewDecision": verdict.pr.get("reviewDecision"),
        },
        "checks": {
            "total": len(verdict.checks),
            "passed": verdict.passed,
            "failed": verdict.failed,
            "pending": verdict.pending,
        },
        "blockers": verdict.blockers,
        "verdict": "READY" if verdict.eligible else "BLOCKED",
    }


def _configure_stdio() -> None:
    """Keep Chinese diagnostics readable in Windows terminals."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except (AttributeError, OSError):
                pass


def main(argv: Sequence[str] | None = None) -> int:
    _configure_stdio()
    parser = argparse.ArgumentParser(description="Conservative GitHub PR merge gate")
    parser.add_argument("--pr", type=int, required=True, help="pull request number")
    parser.add_argument("--repo", help="owner/repo (default: current gh repository)")
    parser.add_argument("--dry-run", action="store_true", help="check only; never merge")
    parser.add_argument("--yes", action="store_true", help="required to actually merge")
    parser.add_argument("--json", action="store_true", help="print a JSON verdict")
    parser.add_argument(
        "--log",
        type=Path,
        default=DEFAULT_LOG,
        help=f"audit log path (default: {DEFAULT_LOG})",
    )
    args = parser.parse_args(argv)

    if args.yes and args.dry_run:
        parser.error("--yes and --dry-run are mutually exclusive")

    try:
        pr = fetch_pr(args.pr, args.repo)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    verdict = evaluate(pr)
    if args.json:
        print(json.dumps(_json_payload(verdict), ensure_ascii=False, indent=2))
    else:
        print(render(verdict))

    if not verdict.eligible:
        return 1
    if args.dry_run:
        return 0
    if not args.yes:
        print("refusing to merge: pass --yes after reviewing the gate", file=sys.stderr)
        return 2

    try:
        merge_pr(args.pr, args.repo)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    log_path = args.log if args.log.is_absolute() else REPO_ROOT / args.log
    try:
        log_merge(verdict, log_path, args.repo)
    except OSError as exc:
        print(f"warning: merged but could not write {log_path}: {exc}", file=sys.stderr)
    print(f"merged PR #{args.pr} (squash, branch deleted)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
