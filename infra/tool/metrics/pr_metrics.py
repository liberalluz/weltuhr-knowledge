#!/usr/bin/env python3
"""C12 weekly PR metrics: lead time, rework, docs share, scope status.

The report is intentionally descriptive, not a target:
- lead time = mergedAt - createdAt;
- rework = PR has at least one commit after its first review;
- docs share = changed docs/ paths / all changed paths;
- scope status = actual files vs a local .batch/<id>/scope.json when one can
  still be matched by PR number or branch; otherwise it is "unknown", not pass.

Only merged PRs are counted. Data comes from `gh pr list` + `gh pr view`.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import statistics
import subprocess
import sys
import tempfile
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Sequence

REPO_ROOT = Path(__file__).resolve().parents[3]
BATCH_ROOT = REPO_ROOT / ".batch"
sys.path.insert(0, str(REPO_ROOT / "infra" / "tool" / "batch"))
from check import PROCESS_PATTERNS, check_paths, matches_any  # noqa: E402

DOC_PREFIX = "docs/"


def run_gh(args: Sequence[str]) -> tuple[int, str, str]:
    gh = shutil.which("gh")
    if gh is None:
        return 3, "", "gh not found in PATH"
    with tempfile.TemporaryDirectory(prefix="metrics-gh-") as tmp:
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


def load_json(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def week_key(when: datetime) -> tuple[str, date]:
    iso = when.isocalendar()
    label = f"{iso.year}-W{iso.week:02d}"
    start = when.date() - timedelta(days=when.weekday())
    return label, start


def load_scopes() -> dict[str, dict[int, dict[str, Any]]]:
    """Index local batch scopes by branch and merged PR number."""
    by_branch: dict[str, dict[str, Any]] = {}
    by_pr: dict[int, dict[str, Any]] = {}
    if BATCH_ROOT.is_dir():
        for child in BATCH_ROOT.iterdir():
            if not child.is_dir():
                continue
            scope = load_json(child / "scope.json")
            if scope is None:
                continue
            state = load_json(child / "state.json") or {}
            merge = load_json(child / "merge.json") or {}
            branch = state.get("branch")
            if isinstance(branch, str) and branch:
                by_branch[branch] = scope
            pr = merge.get("pr")
            if isinstance(pr, int):
                by_pr[pr] = scope
    return {"by_branch": by_branch, "by_pr": by_pr}


def find_scope(
    scopes: dict[str, dict[int, dict[str, Any]]],
    branch: str | None,
    pr: int,
) -> dict[str, Any] | None:
    found = scopes["by_pr"].get(pr)
    if found is not None:
        return found
    if branch:
        return scopes["by_branch"].get(branch)
    return None


def build_record(
    pr: dict[str, Any],
    detail: dict[str, Any],
    scopes: dict[str, dict[int, dict[str, Any]]],
) -> dict[str, Any] | None:
    created = parse_time(pr.get("createdAt"))
    merged = parse_time(pr.get("mergedAt"))
    if created is None or merged is None:
        return None
    lead_hours = max(0.0, (merged - created).total_seconds() / 3600)
    files = [str(f.get("path")) for f in detail.get("files") or [] if f.get("path")]
    docs = [path for path in files if path.startswith(DOC_PREFIX)]
    reviews = detail.get("reviews") or []
    review_times = [parse_time(r.get("submittedAt")) for r in reviews]
    review_times = [t for t in review_times if t is not None]
    first_review = min(review_times) if review_times else None
    commits = detail.get("commits") or []
    post_review = 0
    if first_review is not None:
        for commit in commits:
            committed = parse_time(commit.get("committedDate"))
            if committed is not None and committed > first_review:
                post_review += 1

    scope = find_scope(scopes, pr.get("headRefName"), int(pr["number"]))
    violations = check_paths(files, scope) if scope is not None else []
    scope_status = "unknown" if scope is None else ("fail" if violations else "pass")
    process_hits = [path for path in files if matches_any(path, PROCESS_PATTERNS)]

    label, start = week_key(merged)
    return {
        "number": int(pr["number"]),
        "title": pr.get("title"),
        "url": pr.get("url"),
        "branch": pr.get("headRefName"),
        "createdAt": pr.get("createdAt"),
        "mergedAt": pr.get("mergedAt"),
        "leadHours": round(lead_hours, 2),
        "files": files,
        "docsPaths": docs,
        "docsShare": round(len(docs) / len(files), 4) if files else 0.0,
        "commits": len(commits),
        "reviews": len(reviews),
        "postReviewCommits": post_review,
        "rework": post_review > 0,
        "scopeStatus": scope_status,
        "scopeViolations": violations,
        "processFiles": process_hits,
        "week": label,
        "weekStart": start.isoformat(),
    }


def group_weeks(records: Sequence[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        grouped.setdefault(str(record["week"]), []).append(record)
    rows: list[dict[str, Any]] = []
    for week in sorted(grouped, reverse=True):
        items = grouped[week]
        leads = sorted(float(item["leadHours"]) for item in items)
        n = len(leads)
        p90_index = max(0, math.ceil(n * 0.9) - 1)
        file_count = sum(len(item["files"]) for item in items)
        docs_count = sum(len(item["docsPaths"]) for item in items)
        rows.append(
            {
                "week": week,
                "weekStart": min(str(item["weekStart"]) for item in items),
                "merged": n,
                "leadMedianHours": round(statistics.median(leads), 2),
                "leadP90Hours": round(leads[p90_index], 2),
                "rework": sum(1 for item in items if item["rework"]),
                "docsPaths": docs_count,
                "changedPaths": file_count,
                "docsShare": round(docs_count / file_count, 4) if file_count else 0.0,
                "scopeKnown": sum(1 for item in items if item["scopeStatus"] != "unknown"),
                "scopeFail": sum(1 for item in items if item["scopeStatus"] == "fail"),
                "processPrs": sum(1 for item in items if item["processFiles"]),
            }
        )
    return rows


def render_markdown(
    records: Sequence[dict[str, Any]],
    weeks: Sequence[dict[str, Any]],
    since: str,
) -> str:
    lines = [
        "# PR metrics",
        "",
        f"- Window: merged since `{since}`",
        f"- Merged PRs: {len(records)}",
        "- Definitions: lead = mergedAt - createdAt; rework = at least one commit after the first review;",
        "  docs share = changed `docs/` paths / all changed paths; scope is `unknown` when no local `.batch` scope matches.",
        "",
        "| Week | PRs | Lead median (h) | Lead p90 (h) | Rework | Docs share | Scope known | Scope fail | Process-file PRs |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in weeks:
        lines.append(
            f"| {row['week']} | {row['merged']} | {row['leadMedianHours']} | "
            f"{row['leadP90Hours']} | {row['rework']} | {row['docsShare']:.1%} | "
            f"{row['scopeKnown']} | {row['scopeFail']} | {row['processPrs']} |"
        )
    failures = [record for record in records if record["scopeStatus"] == "fail"]
    if failures:
        lines.extend(["", "## Scope failures", ""])
        for record in failures:
            lines.append(
                f"- PR #{record['number']} `{record['branch']}`: "
                + "; ".join(record["scopeViolations"])
            )
    unknown = [record for record in records if record["scopeStatus"] == "unknown"]
    if unknown:
        lines.extend(
            [
                "",
                f"> Scope unknown for {len(unknown)} PR(s): no matching local `.batch` scope remains.",
            ]
        )
    return "\n".join(lines) + "\n"


def fetch_merged(since: str, limit: int) -> list[dict[str, Any]]:
    code, out, err = run_gh(
        [
            "pr",
            "list",
            "--state",
            "merged",
            "--limit",
            str(limit),
            "--search",
            f"merged:>={since}",
            "--json",
            "number,title,url,createdAt,mergedAt,headRefName",
        ]
    )
    if code != 0:
        raise RuntimeError(err or out or "gh pr list failed")
    prs = json.loads(out)
    details: list[dict[str, Any]] = []
    for pr in prs:
        code, out, err = run_gh(
            [
                "pr",
                "view",
                str(pr["number"]),
                "--json",
                "files,commits,reviews",
            ]
        )
        if code != 0:
            raise RuntimeError(f"gh pr view {pr['number']} failed: {err or out}")
        detail = json.loads(out)
        details.append({**pr, "detail": detail})
    return details


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Weekly PR metrics")
    parser.add_argument(
        "--since",
        default=(date.today() - timedelta(weeks=8)).isoformat(),
        help="merged on/after this date (YYYY-MM-DD)",
    )
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)

    try:
        fetched = fetch_merged(args.since, args.limit)
    except (RuntimeError, json.JSONDecodeError) as exc:
        print(f"metrics: {exc}", file=sys.stderr)
        return 3

    scopes = load_scopes()
    records = [
        record
        for item in fetched
        if (record := build_record(item, item["detail"], scopes)) is not None
    ]
    records.sort(key=lambda item: item["mergedAt"], reverse=True)
    weeks = group_weeks(records)

    if args.json:
        payload = {"since": args.since, "records": records, "weeks": weeks}
        text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    else:
        text = render_markdown(records, weeks, args.since)

    if args.output is not None:
        output = args.output if args.output.is_absolute() else REPO_ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text, encoding="utf-8", newline="\n")
        print(f"report: {output}")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
