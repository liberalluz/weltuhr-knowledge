#!/usr/bin/env python3
"""Scope guard for a weltuhr-knowledge batch.

The guard answers one question: *does the current diff stay inside the paths a
human approved for this batch?* It is intentionally separate from the merge
gate:

* ``merge.py`` checks the pull request's CI/review state before merging.
* ``check.py`` checks the working tree/branch against ``scope.json``.

A scope file is a small JSON contract. ``sign_scope`` records a SHA-256 over
everything except ``approval``; editing ``allowed``/``forbidden`` without
re-signing is detected.

Usage (from the repository root):

    python3 infra/tool/batch/check.py --scope .batch/M2/scope.json
    python3 infra/tool/batch/check.py --scope .batch/M2/scope.json --warn-only
    python3 infra/tool/batch/check.py --scope .batch/M2/scope.json \
        --add app/lib/foo.dart --reason "needed by this batch" --yes

Exit codes:
    0  inside scope / warn-only / add succeeded
    1  out of scope or unapproved scope
    2  missing --yes, missing scope, or missing reason
    3  git/scope-file error
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence

REPO_ROOT = Path(__file__).resolve().parents[3]
ACTIVE_SCOPE = REPO_ROOT / ".batch" / "active"
DEFAULT_BASE = "origin/main"

# Files that change the process itself. A feature batch that touches these is
# almost always either widening scope or weakening a gate; force a process batch.
PROCESS_PATTERNS = (
    ".githooks/**",
    ".github/workflows/**",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/CONTRIBUTING.md",
    ".github/CODEOWNERS",
    "docs/specs/git-conventions.md",
    "infra/tool/batch/**",
)


def _configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except (AttributeError, OSError):
                pass


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Translate a repo-relative glob (with **) into an anchored regex."""
    pattern = pattern.replace("\\", "/").strip("/")
    out: list[str] = ["^"]
    index = 0
    while index < len(pattern):
        if pattern.startswith("**/", index):
            out.append("(?:.*/)?")
            index += 3
        elif pattern.startswith("**", index):
            out.append(".*")
            index += 2
        else:
            char = pattern[index]
            if char == "*":
                out.append("[^/]*")
            elif char == "?":
                out.append("[^/]")
            else:
                out.append(re.escape(char))
            index += 1
    out.append("$")
    return re.compile("".join(out))


def matches_any(path: str, patterns: Iterable[str]) -> bool:
    normalized = path.replace("\\", "/")
    return any(glob_to_regex(pattern).match(normalized) for pattern in patterns)


def scope_hash(scope: dict[str, Any]) -> str:
    payload = {key: value for key, value in scope.items() if key != "approval"}
    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def sign_scope(scope: dict[str, Any], by: str | None = None) -> dict[str, Any]:
    signed = {key: value for key, value in scope.items() if key != "approval"}
    signed["approval"] = {
        "by": by or getpass.getuser(),
        "at": datetime.now(timezone.utc).isoformat(),
        "hash": scope_hash(signed),
    }
    return signed


def verify_scope(scope: dict[str, Any]) -> str | None:
    approval = scope.get("approval")
    if not isinstance(approval, dict) or not approval.get("hash"):
        return "scope 未批准：缺 approval.hash"
    if approval["hash"] != scope_hash(scope):
        return "scope hash 不匹配：scope.json 在批准后被改动，需要重新批准"
    return None


def load_scope(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"scope file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid scope JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise RuntimeError("scope file must contain a JSON object")
    allowed = data.get("allowed")
    if not isinstance(allowed, list) or not all(isinstance(item, str) for item in allowed):
        raise RuntimeError("scope.allowed must be a list of strings")
    forbidden = data.get("forbidden", [])
    if not isinstance(forbidden, list) or not all(isinstance(item, str) for item in forbidden):
        raise RuntimeError("scope.forbidden must be a list of strings")
    return data


def run_git(args: Sequence[str]) -> tuple[int, str, str]:
    """Run git, using temp files instead of pipes for sandbox compatibility."""
    with tempfile.TemporaryDirectory(prefix="batch-git-") as tmp:
        out_path = Path(tmp) / "stdout"
        err_path = Path(tmp) / "stderr"
        with out_path.open("w", encoding="utf-8") as out, err_path.open(
            "w", encoding="utf-8"
        ) as err:
            proc = subprocess.run(
                ["git", *args],
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


def changed_paths(base: str) -> list[str]:
    """Committed changes against base, plus staged/unstaged/untracked work."""
    paths: set[str] = set()
    commands = (
        ["diff", "--name-only", f"{base}...HEAD"],
        ["diff", "--name-only", "HEAD"],
        ["ls-files", "--others", "--exclude-standard"],
    )
    for command in commands:
        code, out, err = run_git(command)
        if code != 0:
            raise RuntimeError(err or f"git {' '.join(command)} exited {code}")
        paths.update(line.strip() for line in out.splitlines() if line.strip())
    return sorted(paths)


def check_paths(paths: Iterable[str], scope: dict[str, Any]) -> list[str]:
    allowed = list(scope.get("allowed") or [])
    forbidden = list(scope.get("forbidden") or [])
    if scope.get("type") != "process":
        forbidden.extend(PROCESS_PATTERNS)

    violations: list[str] = []
    for path in paths:
        normalized = path.replace("\\", "/")
        if matches_any(normalized, forbidden):
            violations.append(f"{normalized}：命中 forbidden/流程文件（需 process 批次或人工批准）")
        elif not matches_any(normalized, allowed):
            violations.append(f"{normalized}：不在 allowed")
    return violations


def resolve_scope(path: Path | None) -> Path:
    if path is not None:
        return path
    if ACTIVE_SCOPE.exists():
        value = ACTIVE_SCOPE.read_text(encoding="utf-8").strip()
        if value:
            candidate = Path(value)
            return candidate if candidate.is_absolute() else REPO_ROOT / candidate
    raise RuntimeError("没有 scope：传 --scope，或由 batch start 写 .batch/active")


def render(scope: dict[str, Any], scope_path: Path, base: str, paths: list[str], violations: list[str], hash_error: str | None) -> str:
    lines = [
        f"Scope: {scope.get('batch', '?')} ({scope.get('type', '?')})",
        f"Scope file: {scope_path}",
        f"Base: {base}",
        f"Changed: {len(paths)} paths",
    ]
    if hash_error:
        lines.append(f"Approval: BLOCKED — {hash_error}")
    if violations:
        lines.append("Violations:")
        lines.extend(f"- {violation}" for violation in violations)
        lines.append("Verdict: BLOCKED")
    else:
        lines.append("Verdict: PASS")
    return "\n".join(lines)


def json_payload(scope: dict[str, Any], scope_path: Path, base: str, paths: list[str], violations: list[str], hash_error: str | None) -> dict[str, Any]:
    return {
        "scope": str(scope_path),
        "batch": scope.get("batch"),
        "type": scope.get("type"),
        "base": base,
        "changed": paths,
        "violations": violations,
        "approvalError": hash_error,
        "verdict": "BLOCKED" if (violations or hash_error) else "PASS",
    }


def add_path(scope_path: Path, path: str, reason: str, approved_by: str | None) -> dict[str, Any]:
    if not reason.strip():
        raise RuntimeError("--reason is required when widening scope")
    scope = load_scope(scope_path)
    allowed = list(scope.get("allowed") or [])
    normalized = path.replace("\\", "/").strip("/")
    if not normalized:
        raise RuntimeError("--add needs a non-empty path")
    if normalized not in allowed:
        allowed.append(normalized)
    scope["allowed"] = allowed
    signed = sign_scope(scope, approved_by)
    scope_path.parent.mkdir(parents=True, exist_ok=True)
    scope_path.write_text(
        json.dumps(signed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return signed


def main(argv: Sequence[str] | None = None) -> int:
    _configure_stdio()
    parser = argparse.ArgumentParser(description="Batch scope guard")
    parser.add_argument("--scope", type=Path, help="path to scope.json")
    parser.add_argument("--base", default=DEFAULT_BASE, help=f"diff base (default: {DEFAULT_BASE})")
    parser.add_argument("--quick", action="store_true", help="scope-only mode for pre-push")
    parser.add_argument("--warn-only", action="store_true", help="report but exit 0")
    parser.add_argument("--add", metavar="PATH", help="add a path to scope (requires --reason --yes)")
    parser.add_argument("--reason", default="", help="reason for widening scope")
    parser.add_argument("--yes", action="store_true", help="confirm scope change")
    parser.add_argument("--by", help="approver name recorded in the scope file")
    parser.add_argument("--json", action="store_true", help="print machine-readable verdict")
    args = parser.parse_args(argv)

    if args.add is not None:
        if not args.yes:
            print("refusing scope change: pass --yes after human approval", file=sys.stderr)
            return 2
        try:
            target = resolve_scope(args.scope)
            signed = add_path(target, args.add, args.reason, args.by)
        except RuntimeError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        print(f"added {args.add} to {target}; new hash {signed['approval']['hash']}")
        print("commit/review the scope change; do not widen scope silently", file=sys.stderr)
        return 0

    try:
        scope_path = resolve_scope(args.scope)
        scope = load_scope(scope_path)
        hash_error = verify_scope(scope)
        paths = changed_paths(args.base)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    violations = check_paths(paths, scope)
    if args.json:
        print(json.dumps(json_payload(scope, scope_path, args.base, paths, violations, hash_error), ensure_ascii=False, indent=2))
    else:
        print(render(scope, scope_path, args.base, paths, violations, hash_error))

    blocked = bool(violations or hash_error)
    if blocked and args.warn_only:
        print("WARN: scope violations ignored (--warn-only)", file=sys.stderr)
        return 0
    return 1 if blocked else 0


if __name__ == "__main__":
    raise SystemExit(main())
