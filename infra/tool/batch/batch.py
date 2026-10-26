#!/usr/bin/env python3
"""Batch state CLI skeleton.

C1 keeps this deliberately small: it discovers a batch directory, reads the
state/scope/card files that later stages will write, and reports where the
batch is. It does not create branches, cards or pull requests; those are C2/C4.

Usage (from the repository root):

    python3 infra/tool/batch/batch.py status
    python3 infra/tool/batch/batch.py status --batch M2 --json
    python3 infra/tool/batch/batch.py list

State layout (all under `.batch/`, gitignored):

    .batch/active                 # optional: path to the current batch dir
    .batch/<id>/state.json        # batch, type, branch, base, created_at
    .batch/<id>/scope.json        # produced by the C2 card/approval step
    .batch/<id>/card.yaml         # produced by C2 (optional here)
    .batch/<id>/evidence.log      # produced by C3/C4 (optional here)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Sequence

REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ROOT = REPO_ROOT / ".batch"

try:
    from check import verify_scope  # same directory; optional for status
except Exception:  # pragma: no cover - only a degraded status path
    verify_scope = None  # type: ignore[assignment]


def _configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except (AttributeError, OSError):
                pass


def run_git(args: Sequence[str]) -> tuple[int, str, str]:
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


def load_json(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def resolve_batch(root: Path, batch_id: str | None) -> Path | None:
    if batch_id:
        candidate = root / batch_id
        return candidate if candidate.is_dir() else None

    active = root / "active"
    if active.exists():
        value = active.read_text(encoding="utf-8").strip()
        if value:
            candidate = Path(value)
            if not candidate.is_absolute():
                candidate = REPO_ROOT / candidate
            if candidate.is_dir():
                return candidate

    candidates: list[Path] = []
    if root.is_dir():
        for child in root.iterdir():
            if not child.is_dir():
                continue
            if any((child / name).exists() for name in ("state.json", "scope.json", "card.yaml")):
                candidates.append(child)
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def current_branch() -> str:
    code, out, _ = run_git(["rev-parse", "--abbrev-ref", "HEAD"])
    return out if code == 0 and out else "(unknown)"


def changed_paths(base: str | None) -> list[str]:
    paths: set[str] = set()
    commands: list[list[str]] = []
    if base:
        commands.append(["diff", "--name-only", f"{base}...HEAD"])
    commands.append(["diff", "--name-only", "HEAD"])
    commands.append(["ls-files", "--others", "--exclude-standard"])
    for command in commands:
        code, out, _ = run_git(command)
        if code == 0:
            paths.update(line.strip() for line in out.splitlines() if line.strip())
    return sorted(paths)


def batch_payload(batch_dir: Path) -> dict[str, Any]:
    state = load_json(batch_dir / "state.json") or {}
    scope = load_json(batch_dir / "scope.json")
    card = next(
        (batch_dir / name for name in ("card.yaml", "card.yml", "card.md") if (batch_dir / name).exists()),
        None,
    )
    evidence = batch_dir / "evidence.log"

    base = state.get("base")
    changed = changed_paths(base if isinstance(base, str) else None)
    approval_error = None
    if scope is not None and verify_scope is not None:
        approval_error = verify_scope(scope)

    if card is None:
        stage = "card"
    elif scope is None:
        stage = "scope"
    elif evidence.exists():
        stage = "pr"
    else:
        stage = "check"

    return {
        "batch": state.get("batch") or batch_dir.name,
        "type": state.get("type") or (scope or {}).get("type") or "(unknown)",
        "stateDir": str(batch_dir),
        "branch": state.get("branch") or current_branch(),
        "base": base or "(unknown)",
        "changed": changed,
        "scope": {
            "present": scope is not None,
            "allowed": len((scope or {}).get("allowed") or []),
            "forbidden": len((scope or {}).get("forbidden") or []),
            "approvalError": approval_error,
        },
        "card": str(card) if card else None,
        "evidence": str(evidence) if evidence.exists() else None,
        "stage": stage,
        "next": "C2 card" if stage == "card" else "implement / C3 check",
    }


def render_status(payload: dict[str, Any]) -> str:
    scope = payload["scope"]
    approval = "missing"
    if scope["present"]:
        approval = scope["approvalError"] or "OK"
    lines = [
        f"Batch: {payload['batch']} ({payload['type']})",
        f"State: {payload['stateDir']}",
        f"Branch: {payload['branch']}",
        f"Base: {payload['base']}",
        f"Changed: {len(payload['changed'])} paths",
        f"Scope: {scope['allowed']} allowed / {scope['forbidden']} forbidden; approval: {approval}",
        f"Card: {payload['card'] or 'missing'}",
        f"Evidence: {payload['evidence'] or 'missing'}",
        f"Stage: {payload['stage']}",
        f"Next: {payload['next']}",
    ]
    return "\n".join(lines)


def command_status(args: argparse.Namespace) -> int:
    root = args.root if args.root.is_absolute() else REPO_ROOT / args.root
    batch_dir = resolve_batch(root, args.batch)
    if batch_dir is None:
        print(f"no batch found under {root}", file=sys.stderr)
        return 1
    payload = batch_payload(batch_dir)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(render_status(payload))
    return 0


def command_list(args: argparse.Namespace) -> int:
    root = args.root if args.root.is_absolute() else REPO_ROOT / args.root
    rows: list[dict[str, Any]] = []
    if root.is_dir():
        for child in sorted(root.iterdir(), key=lambda path: path.name):
            if child.is_dir() and any(
                (child / name).exists() for name in ("state.json", "scope.json", "card.yaml")
            ):
                state = load_json(child / "state.json") or {}
                scope = load_json(child / "scope.json") or {}
                rows.append(
                    {
                        "batch": state.get("batch") or child.name,
                        "type": state.get("type") or scope.get("type") or "(unknown)",
                        "dir": str(child),
                    }
                )
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    elif rows:
        for row in rows:
            print(f"{row['batch']}\t{row['type']}\t{row['dir']}")
    else:
        print(f"no batches under {root}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Batch state CLI skeleton")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="batch state root")
    subparsers = parser.add_subparsers(dest="command", required=True)

    status = subparsers.add_parser("status", help="show one batch")
    status.add_argument("--batch", help="batch id; defaults to .batch/active or latest")
    status.add_argument("--json", action="store_true")
    status.set_defaults(func=command_status)

    listing = subparsers.add_parser("list", help="list known batches")
    listing.add_argument("--json", action="store_true")
    listing.set_defaults(func=command_list)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    _configure_stdio()
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
