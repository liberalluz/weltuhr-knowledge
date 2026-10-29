#!/usr/bin/env python3
"""Batch state and card CLI.

C2 adds the human-owned batch card:

    batch plan <id> --type ... --goal ... --allowed ...   # draft card.yaml
    batch approve <id> --chat --confirm <hash8>           # human chat confirmation
    batch start <id> [--no-branch]                        # branch + state + scope
    batch status [--batch <id>] [--json]
    batch list [--json]

The command is deliberately thin: it writes state under `.batch/`, then the
existing scope guard and merge gate enforce the result.
"""

from __future__ import annotations

import argparse
import fnmatch
import getpass
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

from card import approve_card, card_hash, read_card, verify_card, write_card
from check import PROCESS_PATTERNS, check_paths, sign_scope, verify_scope

REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ROOT = REPO_ROOT / ".batch"

# Changing the batch tooling or the hooks cannot be tested by any other step,
# so these run whenever a batch touches infra/tool/batch or .githooks.
BATCH_TEST_FILES = (
    "infra/tool/batch/tests/test_batch_card.py",
    "infra/tool/batch/tests/test_batch_check.py",
    "infra/tool/batch/tests/test_batch_cli.py",
    "infra/tool/batch/tests/test_batch_merge.py",
    "infra/tool/batch/tests/test_batch_pr.py",
    "infra/tool/batch/tests/test_merge_gate.py",
    "infra/tool/batch/tests/test_scope_guard.py",
    "infra/tool/batch/tests/test_skill_lint.py",
)


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


def root_path(root: Path) -> Path:
    return root if root.is_absolute() else REPO_ROOT / root


def active_batch(root: Path) -> Path | None:
    active = root / "active"
    if not active.exists():
        return None
    try:
        value = active.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    if not value:
        return None
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = REPO_ROOT / candidate
    return candidate if candidate.is_dir() else None


def generate_batch_id(root: Path) -> str:
    prefix = datetime.now().strftime("%Y%m%d")
    for _ in range(50):
        candidate = f"{prefix}-{secrets.token_hex(3)}"
        if not (root / candidate).exists():
            return candidate
    raise RuntimeError("could not allocate a free batch id")


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


def diff_status(base: str) -> dict[str, str]:
    """Map each changed path to A (added) / M (modified) / D (deleted)."""
    code, out, _ = run_git(["diff", "--name-status", f"{base}...HEAD"])
    if code != 0:
        return {}
    statuses: dict[str, str] = {}
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        flag = parts[0][:1]
        statuses[parts[-1]] = "A" if flag == "A" else "D" if flag == "D" else "M"
    return statuses


def diff_line_count(base: str) -> int:
    """Count added+deleted lines on the branch plus the working tree."""
    total = 0
    for command in (
        ["diff", "--numstat", f"{base}...HEAD"],
        ["diff", "--numstat", "HEAD"],
    ):
        code, out, _ = run_git(command)
        if code != 0:
            continue
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            added, deleted = parts[0], parts[1]
            if added.isdigit():
                total += int(added)
            if deleted.isdigit():
                total += int(deleted)
    return total


def read_card_safe(batch_dir: Path) -> tuple[dict[str, Any] | None, str | None]:
    path = batch_dir / "card.yaml"
    if not path.exists():
        return None, None
    try:
        return read_card(path), None
    except (OSError, ValueError) as exc:
        return None, str(exc)


def batch_payload(batch_dir: Path) -> dict[str, Any]:
    state = load_json(batch_dir / "state.json") or {}
    scope = load_json(batch_dir / "scope.json")
    card, card_error = read_card_safe(batch_dir)
    evidence = batch_dir / "evidence.log"
    merge = load_json(batch_dir / "merge.json")

    base = state.get("base")
    changed = changed_paths(base if isinstance(base, str) else None)
    approval_error = None
    if scope is not None:
        approval_error = verify_scope(scope)
    card_approval_error = verify_card(card) if card is not None else None

    if merge is not None:
        stage = "merged"
    elif card is None:
        stage = "card"
    elif card_approval_error:
        stage = "approve"
    elif scope is None:
        stage = "start"
    elif evidence.exists():
        stage = "pr"
    else:
        stage = "check"

    evidence_ok = False
    if evidence.exists():
        try:
            evidence_ok = "RESULT: PASS" in evidence.read_text(encoding="utf-8")
        except OSError:
            evidence_ok = False
    if stage == "pr" and not evidence_ok:
        stage = "check"

    active_dir = active_batch(batch_dir.parent)
    is_active = active_dir is not None and active_dir.resolve() == batch_dir.resolve()

    return {
        "batch": state.get("batch") or (card or {}).get("batch") or batch_dir.name,
        "type": state.get("type")
        or (card or {}).get("type")
        or (scope or {}).get("type")
        or "(unknown)",
        "active": is_active,
        "owner": state.get("owner") or "(unknown)",
        "stateDir": str(batch_dir),
        "branch": state.get("branch") or (card or {}).get("branch") or current_branch(),
        "base": base or (card or {}).get("base") or "(unknown)",
        "changed": changed,
        "card": {
            "present": card is not None,
            "error": card_error,
            "approvalError": card_approval_error,
            "goal": (card or {}).get("goal"),
        },
        "scope": {
            "present": scope is not None,
            "allowed": len((scope or {}).get("allowed") or []),
            "forbidden": len((scope or {}).get("forbidden") or []),
            "approvalError": approval_error,
        },
        "evidence": {
            "path": str(evidence) if evidence.exists() else None,
            "ok": evidence_ok,
        },
        "merge": merge,
        "stage": stage,
        "next": {
            "card": "batch plan",
            "approve": "batch approve",
            "start": "batch start",
            "check": "implement / C3 check",
            "pr": "C4 batch pr",
            "merged": "post-merge: fetch main",
        }[stage],
    }


def render_status(payload: dict[str, Any]) -> str:
    scope = payload["scope"]
    card = payload["card"]
    approval = "missing"
    if scope["present"]:
        approval = scope["approvalError"] or "OK"
    card_approval = "missing"
    if card["present"]:
        card_approval = card["error"] or card["approvalError"] or "OK"
    lines = [
        f"Batch: {payload['batch']} ({payload['type']})",
        f"State: {payload['stateDir']}",
        f"Active: {'yes' if payload.get('active') else 'no'}",
        f"Owner: {payload.get('owner')}",
        f"Branch: {payload['branch']}",
        f"Base: {payload['base']}",
        f"Changed: {len(payload['changed'])} paths",
        f"Card: {card_approval}",
        f"Scope: {scope['allowed']} allowed / {scope['forbidden']} forbidden; approval: {approval}",
        f"Evidence: {payload['evidence']['path'] or 'missing'}"
        + (" (PASS)" if payload['evidence']['ok'] else " (not PASS)"),
        f"Stage: {payload['stage']}",
        f"Next: {payload['next']}",
    ]
    merge = payload.get("merge")
    if isinstance(merge, dict):
        lines.insert(-2, f"Merged: PR #{merge.get('pr')} {merge.get('sha') or ''}".rstrip())
    return "\n".join(lines)


def find_bash() -> str | None:
    configured = os.environ.get("BASH")
    if configured:
        return configured
    if os.name == "nt":
        program_files = Path(os.environ.get("ProgramFiles", r"C:\Program Files"))
        for candidate in (
            program_files / "Git" / "bin" / "bash.exe",
            program_files / "Git" / "usr" / "bin" / "bash.exe",
        ):
            if candidate.exists():
                return str(candidate)
    return shutil.which("bash")


def run_command(command: Sequence[str], cwd: Path) -> tuple[int, str, str]:
    argv: list[str] | str = list(command)
    shell = False
    env = os.environ.copy()
    if any("pr-body" in str(part) for part in command):
        # Git Bash may default to a non-UTF-8 locale when spawned from Python;
        # the checker's full-width semicolon pattern then operates on bytes.
        env["LANG"] = "C.UTF-8"
        env["LC_ALL"] = "C.UTF-8"
    if os.name == "nt":
        executable = shutil.which(argv[0])
        if executable and executable.lower().endswith((".bat", ".cmd")):
            # Dart/Flutter on Windows are .bat shims; CreateProcess cannot run
            # them directly. shell=True goes through cmd.exe with one command
            # string, avoiding the quote-escaping trap of `/c` + a list.
            argv = subprocess.list2cmdline([executable, *argv[1:]])
            shell = True
    with tempfile.TemporaryDirectory(prefix="batch-cmd-") as tmp:
        out_path = Path(tmp) / "stdout"
        err_path = Path(tmp) / "stderr"
        with out_path.open("w", encoding="utf-8") as out, err_path.open(
            "w", encoding="utf-8"
        ) as err:
            proc = subprocess.run(
                argv,
                cwd=cwd,
                shell=shell,
                stdout=out,
                stderr=err,
                text=True,
                env=env,
            )
        return (
            proc.returncode,
            out_path.read_text(encoding="utf-8", errors="replace"),
            err_path.read_text(encoding="utf-8", errors="replace"),
        )


def python_command() -> str:
    for name in ("python", "python3"):
        if shutil.which(name):
            return name
    return "python"


def display_path(value: str | Path) -> str:
    """Render a path the way a reader should see it, never as a host absolute path.

    Commands are executed with whatever absolute path the platform needs; only
    the text written to evidence.log and printed by --dry-run goes through here.
    """
    text = str(value)
    if not os.path.isabs(text):
        return text
    try:
        return Path(text).resolve().relative_to(REPO_ROOT).as_posix() or "."
    except ValueError:
        return Path(text).name


def display_command(command: Sequence[str]) -> str:
    return " ".join(display_path(part) for part in command)


def planned_steps(
    changed: Sequence[str],
    base: str,
    *,
    quick: bool,
    no_tests: bool,
    no_format: bool,
    pr_body: Path | None,
) -> list[tuple[str, list[str], Path]]:
    if quick:
        return []
    steps: list[tuple[str, list[str], Path]] = []
    dart_files = [path for path in changed if path.endswith(".dart")]
    if dart_files and not no_format:
        steps.append(
            (
                "format",
                ["dart", "format", "--output=none", "--set-exit-if-changed", *dart_files],
                REPO_ROOT,
            )
        )

    app_changed = any(path.startswith("app/") for path in changed)
    # D1-D3 cross-check the ledger against test landing points under
    # `app/test/`, so a test-only change can still leave an unregistered case.
    # Keying this on the `docs/` prefix alone skips exactly that case: the step
    # that would have caught it never runs.
    docs_changed = any(path.startswith(("docs/", "app/test/")) for path in changed)
    if app_changed:
        steps.append(("analyze", ["flutter", "analyze"], REPO_ROOT / "app"))
        steps.append(("lint", ["dart", "run", "tool/lint/check.dart"], REPO_ROOT / "app"))
    if docs_changed:
        steps.append(("docs", ["dart", "run", "tool/docs/check.dart"], REPO_ROOT / "app"))
    if any(path.startswith("content/") for path in changed):
        # --check rebuilds twice and compares sha256; it writes nothing.
        steps.append(("content", [python_command(), "content/tools/build.py", "--check"], REPO_ROOT))
    if any(path.startswith("server/") for path in changed) and (
        REPO_ROOT / "server" / "pubspec.yaml"
    ).exists():
        # The server package does not exist yet; the guard keeps check green
        # until it is created, then these steps switch on by themselves.
        steps.append(("server-analyze", ["dart", "analyze"], REPO_ROOT / "server"))
        if not no_tests:
            steps.append(("server-tests", ["dart", "test", "--reporter", "compact"], REPO_ROOT / "server"))
    if any(path.startswith(".agents/skills/") for path in changed):
        steps.append(("skills", [python_command(), "-B", "infra/tool/batch/skill_lint.py"], REPO_ROOT))
    if app_changed and not no_tests:
        steps.append(("tests", ["flutter", "test", "--reporter", "compact"], REPO_ROOT / "app"))
    if any(path.startswith(("infra/tool/batch/", ".githooks/")) for path in changed):
        for test_file in BATCH_TEST_FILES:
            steps.append(
                (f"batch-tests/{Path(test_file).name}", [python_command(), test_file], REPO_ROOT)
            )
        steps.append(
            (
                "pr-body-self-test",
                [find_bash() or "bash", ".githooks/pr-body", "--self-test"],
                REPO_ROOT,
            )
        )

    if pr_body is not None:
        bash = find_bash()
        if not bash:
            steps.append(("pr-body", ["bash", ".githooks/pr-body"], REPO_ROOT))
        else:
            steps.append(
                (
                    "pr-body",
                    [
                        bash,
                        ".githooks/pr-body",
                        "--file",
                        pr_body.as_posix(),
                        "--diff-base",
                        base,
                    ],
                    REPO_ROOT,
                )
            )
    return steps


def run_gh(args: Sequence[str], timeout: float | None = None) -> tuple[int, str, str]:
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
                timeout=timeout,
            )
        return (
            proc.returncode,
            out_path.read_text(encoding="utf-8", errors="replace").strip(),
            err_path.read_text(encoding="utf-8", errors="replace").strip(),
        )


def validate_body(body_path: Path, base: str) -> int:
    bash = find_bash()
    if not bash:
        print("error: bash not found; cannot run pr-body", file=sys.stderr)
        return 3
    code, out, err = run_command(
        [
            bash,
            ".githooks/pr-body",
            "--file",
            body_path.as_posix(),
            "--diff-base",
            base,
        ],
        REPO_ROOT,
    )
    if out.strip():
        print(out.strip())
    if err.strip():
        print(err.strip(), file=sys.stderr)
    return code


PLATFORM_ALIASES = {"windows": "Windows", "macos": "macOS", "ios": "iOS"}
PLATFORM_NONE = {"", "none", "null", "无"}


def normalize_platforms(raw: Sequence[Any]) -> list[str]:
    """Map card platform names to the canonical spellings pr-body accepts."""
    platforms = []
    for item in raw:
        name = str(item or "").strip()
        if name.lower() in PLATFORM_NONE:
            continue
        canonical = PLATFORM_ALIASES.get(name.lower(), name)
        if canonical not in platforms:
            platforms.append(canonical)
    return platforms


def short_base(base: str) -> str:
    """Render a base commit as 7 chars, widening to 12 / 40 while ambiguous."""
    text = str(base or "").strip()
    if len(text) != 40 or any(ch not in "0123456789abcdef" for ch in text):
        return text or "(unknown)"
    for width in (7, 12):
        code, out, _ = run_git(
            ["rev-parse", "--verify", "--quiet", f"{text[:width]}^{{commit}}"]
        )
        if code == 0 and out.strip() == text:
            return text[:width]
    return text


def actor_identity() -> str:
    """Approver identity: GitHub login first, then git identity, then OS user."""
    try:
        code, out, _ = run_gh(["api", "user", "--jq", ".login"], timeout=10)
    except (subprocess.TimeoutExpired, RuntimeError):
        code, out = 1, ""
    if code == 0 and out:
        return out
    code, out, _ = run_git(["config", "user.name"])
    if code == 0 and out:
        return out
    return getpass.getuser()


def branch_for_base(base: str) -> str | None:
    """Map a base to a branch name; `gh pr create --base` rejects bare shas."""
    text = str(base or "").strip()
    if not text:
        return None
    for prefix in ("refs/heads/", "refs/remotes/"):
        if text.startswith(prefix):
            text = text[len(prefix):]
    if text.startswith("origin/"):
        return text[len("origin/"):]
    if len(text) != 40 or any(ch not in "0123456789abcdef" for ch in text):
        return text
    code, out, _ = run_git(
        [
            "for-each-ref",
            "--points-at",
            text,
            "--format=%(refname:short)",
            "refs/remotes/origin",
        ]
    )
    if code != 0:
        return None
    names = [
        line.strip()[len("origin/"):]
        for line in out.splitlines()
        if line.strip().startswith("origin/") and line.strip() != "origin/HEAD"
    ]
    if not names:
        return None
    return "main" if "main" in names else names[0]


def untouched_paths(card: dict[str, Any], changed: Sequence[str]) -> list[str]:
    """Paths named literally in card.allowed that this batch never touched.

    Glob entries cannot be enumerated, so they are skipped; a batch whose whole
    scope is globs therefore reports zero untouched paths.
    """
    touched = set(changed)
    names = [str(item) for item in (card.get("allowed") or [])]
    return sorted(
        name for name in names if not any(ch in name for ch in "*?[") and name not in touched
    )


def note_map(card: dict[str, Any]) -> dict[str, str]:
    notes: dict[str, str] = {}
    for raw in card.get("notes") or []:
        text = str(raw)
        if "=" not in text:
            continue
        path, note = text.split("=", 1)
        if path.strip() and note.strip():
            notes[path.strip()] = note.strip()
    return notes


def build_pr_body(
    card: dict[str, Any],
    changed: Sequence[str],
    evidence_text: str,
    statuses: dict[str, str] | None = None,
    notes: dict[str, str] | None = None,
) -> str:
    goals = str(card.get("goal") or f"批次 {card.get('batch') or '?'}")
    platforms = normalize_platforms(card.get("platforms") or [])
    evidence_summary = "\n".join(
        line
        for line in evidence_text.splitlines()
        if line.startswith("$ ") or line.startswith("RESULT:")
    )
    if not evidence_summary:
        evidence_summary = "scope=PASS"

    paths = [path for path in changed if path]
    stacks = {
        path.split("/", 1)[0]
        for path in paths
        if "/" in path and path.split("/", 1)[0] in {"app", "server", "content", "infra"}
    }

    lines = ["## 变更摘要", "", goals, "", "## 影响面", ""]
    if platforms:
        lines.append("- **平台**：")
        for platform in platforms:
            lines.append(f"  - {platform}：未测 —— card 声明，见「验证」的未验项")
    else:
        lines.append("- **平台**：无")
    lines.extend(
        [
            f"- **类型**：{card.get('type') or '(unknown)'}",
            "- **兼容与回滚**：无",
        ]
    )
    # The tech-stack group only appears when the diff spans >= 2 stacks; a 0- or
    # 1-stack batch leaves it out entirely (the hook judges both directions).
    if len(stacks) >= 2:
        lines.extend(
            [
                "- **技术栈**：",
                "",
                "| 模块 | 是否改动 | 说明 |",
                "|---|---|---|",
                *[
                    f"| {stack} | {'是' if stack in stacks else '否'} | "
                    f"{'本批有改动' if stack in stacks else '未改动'} |"
                    for stack in ("app", "server", "content", "infra")
                ],
            ]
        )
    status_map = statuses or {}
    added = sum(1 for path in paths if status_map.get(path) == "A")
    deleted = sum(1 for path in paths if status_map.get(path) == "D")
    modified = len(paths) - added - deleted
    untouched = untouched_paths(card, paths)

    lines.extend(
        [
            "",
            "## 自审留痕",
            "",
            f"- **分支基线**：从 `{short_base(str(card.get('base') or ''))}` 切出，与 `main` 无分叉",
            f"- **改动面**：动了 `{len(paths)}` 条路径，归为 `{len(paths)}` 项；未动 `{len(untouched)}` 处",
        ]
    )
    if status_map:
        lines.append(f"  - 分类：新增 `{added}` · 修改 `{modified}` · 删除 `{deleted}`")
    note_by_path = notes or {}
    for path in paths:
        note = note_by_path.get(path, "更新")
        lines.append(f"  - {note}：`{path}`")
    for path in untouched:
        lines.append(f"  - 未动：`{path}`")

    lines.extend(
        [
            "- **版号**：不变 —— 未在 card 中声明版本变更",
            "- **反证**：本笔在推翻「改动超出 scope 也能推上去」。",
            "  - 假设 scope 比对能拦住越界 → 跑 batch check → PASS",
            "  - **未验**：见 evidence.log 的跳过步骤",
            "- **如实登记**：",
            "  - 由 batch pr 从 card 与 evidence 生成",
            "",
            "## 验证",
            "",
            "- **命令与输出**：",
            "",
            "  ```text",
            *[f"  {line}" for line in evidence_summary.splitlines()],
            "  ```",
            "",
            "- **测试设计**：batch check 的 scope 比对 + 按改动路径选择的步骤",
            "- **未验**：见 evidence.log 的跳过步骤",
            "",
            "## UI 证据",
            "",
            "无",
            "",
            "## 交付物",
            "",
            "无",
            "",
            "## AI 参与",
            "",
            "- **级别**：pair",
            "- **AI 生成**：PR 正文",
            "- **人核**：card、scope 与 evidence",
            "",
            "## 关联",
            "",
            f"- 批次号：`{card.get('batch') or '?'}`",
            "",
            "## 评审提示",
            "",
            "重点看 scope 与 evidence；本批平台影响见「影响面」。",
        ]
    )
    return "\n".join(lines) + "\n"


def command_pr(args: argparse.Namespace) -> int:
    root = root_path(args.root)
    batch_dir = resolve_batch(root, args.batch)
    if batch_dir is None:
        print(f"no batch found under {root}", file=sys.stderr)
        return 1
    state = load_json(batch_dir / "state.json") or {}
    card, card_error = read_card_safe(batch_dir)
    scope = load_json(batch_dir / "scope.json")
    if card is None:
        print(f"card not found or invalid: {card_error}", file=sys.stderr)
        return 1
    if verify_card(card):
        print(verify_card(card), file=sys.stderr)
        return 1
    if scope is None:
        print("scope not found; run batch start", file=sys.stderr)
        return 1
    if verify_scope(scope):
        print(verify_scope(scope), file=sys.stderr)
        return 1

    evidence = batch_dir / "evidence.log"
    if not evidence.exists() or "RESULT: PASS" not in evidence.read_text(encoding="utf-8"):
        print("evidence is missing or not PASS; run batch check", file=sys.stderr)
        return 1

    base = args.base or state.get("base") or card.get("base") or "origin/main"
    changed = changed_paths(str(base))
    budget = int(card.get("size_budget") or 0)
    if budget:
        line_count = diff_line_count(str(base))
        if line_count > budget:
            print(
                f"refusing to create PR: {line_count} changed lines exceed size_budget {budget}; split the batch",
                file=sys.stderr,
            )
            return 1
    if args.prepare and args.create:
        print("--prepare and --create are mutually exclusive", file=sys.stderr)
        return 2
    if args.body_file is not None and args.body_out is not None:
        print("--body-file cannot be combined with --body-out", file=sys.stderr)
        return 2
    if args.confirm and not args.create:
        print("--confirm is only valid with --create", file=sys.stderr)
        return 2
    if args.create and args.body_file is None:
        print(
            "refusing to create PR: --create requires --body-file (handwritten body)",
            file=sys.stderr,
        )
        return 2

    if args.body_file is not None:
        body_path = args.body_file
        if not body_path.is_absolute():
            body_path = REPO_ROOT / body_path
        if not body_path.exists():
            print(f"body file not found: {body_path}", file=sys.stderr)
            return 1
        body = body_path.read_text(encoding="utf-8")
    else:
        body = build_pr_body(
            card,
            changed,
            evidence.read_text(encoding="utf-8"),
            diff_status(str(base)),
            note_map(card),
        )
        body_path = args.body_out
        if body_path is None:
            body_path = batch_dir / "pr-body.md"
        elif not body_path.is_absolute():
            body_path = REPO_ROOT / body_path
        body_path.parent.mkdir(parents=True, exist_ok=True)
        body_path.write_text(body, encoding="utf-8", newline="\n")
    print(f"body: {body_path}")
    digest = hashlib.sha256(body.encode("utf-8")).hexdigest()
    print(f"body hash: {digest} (confirm: {digest[:8]})")

    batch_id = str(card.get("batch") or "")
    if batch_id and not re.search(
        rf"(?m)^- 批次号：\s*`?{re.escape(batch_id)}`?\s*$", body
    ):
        print(
            f"body is missing the matching batch marker: - 批次号：`{batch_id}`",
            file=sys.stderr,
        )
        return 1

    code = validate_body(body_path, str(base))
    if code != 0:
        print("pr-body validation failed; fix the body then rerun", file=sys.stderr)
        return 1
    if not args.create:
        print(
            "body validated; edit it, then rerun with "
            "--create --body-file <path> --confirm <body-hash8>"
        )
        return 0
    if not args.confirm:
        print("refusing to create PR: pass --confirm <body-hash8>", file=sys.stderr)
        return 2
    if args.confirm != digest[:8]:
        print(
            f"body hash mismatch: expected {digest[:8]}, got {args.confirm}",
            file=sys.stderr,
        )
        return 1

    branch = state.get("branch") or card.get("branch")
    if not branch:
        print("branch missing from state/card", file=sys.stderr)
        return 1
    base_branch = branch_for_base(str(base))
    if base_branch is None:
        print(
            f"cannot resolve base {base!r} to a branch name; pass --base <branch> explicitly",
            file=sys.stderr,
        )
        return 1
    title = args.title
    if not title:
        title_code, title_out, _ = run_git(["log", "-1", "--format=%s"])
        title = title_out if title_code == 0 and title_out else f"batch: {card.get('batch')}"
    code, out, err = run_gh(
        [
            "pr",
            "create",
            "--base",
            base_branch,
            "--head",
            str(branch),
            "--title",
            str(title),
            "--body-file",
            str(body_path),
        ]
    )
    if code != 0:
        print(f"error: gh pr create failed: {err or out}", file=sys.stderr)
        return 3
    print(out)
    return 0


def run_merge_gate(pr: int, *, yes: bool, dry_run: bool) -> int:
    command = [
        sys.executable,
        "-B",
        str(REPO_ROOT / "infra" / "tool" / "batch" / "merge.py"),
        "--pr",
        str(pr),
    ]
    if dry_run:
        command.append("--dry-run")
    elif yes:
        command.append("--yes")
    code, out, err = run_command(command, REPO_ROOT)
    if out.strip():
        print(out.strip())
    if err.strip():
        print(err.strip(), file=sys.stderr)
    return code


def command_merge(args: argparse.Namespace) -> int:
    root = root_path(args.root)
    batch_dir = resolve_batch(root, args.batch)
    if batch_dir is None:
        print(f"no batch found under {root}", file=sys.stderr)
        return 1
    state = load_json(batch_dir / "state.json") or {}
    card, card_error = read_card_safe(batch_dir)
    scope = load_json(batch_dir / "scope.json")
    if card is None:
        print(f"card not found or invalid: {card_error}", file=sys.stderr)
        return 1
    if verify_card(card):
        print(verify_card(card), file=sys.stderr)
        return 1
    if scope is None or verify_scope(scope):
        print("scope missing or invalid; run batch start", file=sys.stderr)
        return 1
    evidence = batch_dir / "evidence.log"
    if not evidence.exists() or "RESULT: PASS" not in evidence.read_text(encoding="utf-8"):
        print("evidence is missing or not PASS; run batch check", file=sys.stderr)
        return 1
    if not args.dry_run and not args.yes:
        print("refusing merge: pass --yes (or --dry-run)", file=sys.stderr)
        return 2

    code, out, err = run_gh(
        ["pr", "view", str(args.pr), "--json", "headRefName,state,number"]
    )
    if code != 0:
        print(f"error: gh pr view failed: {err or out}", file=sys.stderr)
        return 3
    try:
        head = json.loads(out)
    except json.JSONDecodeError:
        print("error: gh pr view returned invalid JSON", file=sys.stderr)
        return 3
    expected_branch = state.get("branch") or card.get("branch")
    if expected_branch and head.get("headRefName") != expected_branch:
        print(
            f"refusing merge: PR head {head.get('headRefName')} != card branch {expected_branch}",
            file=sys.stderr,
        )
        return 1

    gate_code = run_merge_gate(args.pr, yes=args.yes, dry_run=args.dry_run)
    if gate_code != 0:
        return gate_code
    if args.dry_run:
        print("dry-run: merge gate passed; not merged")
        return 0

    record = {
        "batch": state.get("batch") or card.get("batch") or batch_dir.name,
        "pr": args.pr,
        "branch": expected_branch,
        "merged_at": datetime.now(timezone.utc).isoformat(),
    }
    code, out, err = run_gh(
        ["pr", "view", str(args.pr), "--json", "number,title,mergeCommit,state"]
    )
    if code == 0:
        try:
            merged = json.loads(out)
            record["title"] = merged.get("title")
            record["sha"] = (merged.get("mergeCommit") or {}).get("oid")
        except json.JSONDecodeError:
            pass
    (batch_dir / "merge.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    active = root / "active"
    if active.exists():
        value = active.read_text(encoding="utf-8").strip()
        candidate = Path(value)
        if not candidate.is_absolute():
            candidate = REPO_ROOT / candidate
        if candidate.resolve() == batch_dir.resolve():
            active.unlink()

    print(f"merged PR #{args.pr}; next: fetch main and switch to it")
    return 0


def command_check(args: argparse.Namespace) -> int:
    root = root_path(args.root)
    batch_dir = resolve_batch(root, args.batch)
    if batch_dir is None:
        print(f"no batch found under {root}", file=sys.stderr)
        return 1
    state = load_json(batch_dir / "state.json") or {}
    scope = load_json(batch_dir / "scope.json")
    if scope is None:
        print(f"scope not found: {batch_dir / 'scope.json'}", file=sys.stderr)
        return 1

    base = args.base or state.get("base") or "origin/main"
    changed = changed_paths(str(base))
    hash_error = verify_scope(scope)
    violations = check_paths(changed, scope)
    scope_ok = hash_error is None and not violations

    print(f"Batch: {state.get('batch') or batch_dir.name}")
    print(f"Base: {base}")
    print(f"Changed: {len(changed)} paths")
    if hash_error:
        print(f"[FAIL] scope: {hash_error}")
    elif violations:
        print("[FAIL] scope:")
        for violation in violations:
            print(f"  - {violation}")
    else:
        print("[ok] scope")

    if args.quick:
        return 0 if scope_ok else 1

    card, _ = read_card_safe(batch_dir)
    budget = int((card or {}).get("size_budget") or 0)
    line_count = diff_line_count(str(base)) if budget else 0
    budget_ok = not budget or line_count <= budget
    if budget:
        status = "ok" if budget_ok else "FAIL"
        print(f"[{status}] size budget: {line_count} lines <= {budget}" if budget_ok else f"[FAIL] size budget: {line_count} lines > {budget}")

    pr_body = args.pr_body
    if pr_body is not None and not pr_body.is_absolute():
        pr_body = REPO_ROOT / pr_body
    steps = planned_steps(
        changed,
        str(base),
        quick=False,
        no_tests=args.no_tests,
        no_format=args.no_format,
        pr_body=pr_body,
    )

    if args.dry_run:
        for name, command, cwd in steps:
            print(f"[plan] {name}: {display_command(command)} (cwd={display_path(cwd)})")
        return 0 if (scope_ok and budget_ok) else 1

    lines = [
        f"# batch check {state.get('batch') or batch_dir.name}",
        f"at={datetime.now(timezone.utc).isoformat()}",
        f"base={base}",
        f"changed={len(changed)}",
        f"scope={'PASS' if scope_ok else 'FAIL'}",
        f"size_budget={'PASS' if budget_ok else 'FAIL'} ({line_count}/{budget or 'none'})",
    ]
    if hash_error:
        lines.append(f"scope-error={hash_error}")
    for violation in violations:
        lines.append(f"scope-violation={violation}")

    overall = scope_ok and budget_ok
    if scope_ok:
        for name, command, cwd in steps:
            code, out, err = run_command(command, cwd)
            ok = code == 0
            overall = overall and ok
            print(f"[{'ok' if ok else 'FAIL'}] {name} (exit {code})")
            lines.append(f"$ {display_command(command)}")
            lines.append(f"exit={code}")
            if out.strip():
                lines.append(out[-4000:])
            if err.strip():
                lines.append(err[-4000:])
            if not ok:
                print((out or err).strip()[-2000:])
    lines.append(f"RESULT: {'PASS' if overall else 'FAIL'}")

    evidence = batch_dir / "evidence.log"
    evidence.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"evidence: {evidence}")
    print(f"result: {'PASS' if overall else 'FAIL'}")
    return 0 if overall else 1


_LEDGER_PROBE = "docs/specs/controlled/probe.md"


def scope_mutex_error(allowed: Sequence[str], forbidden: Sequence[str]) -> str | None:
    """Reject a card whose test scope and forbidden ledger cannot both hold.

    A test-only change still requires the ledger row (D1/D3 check both
    directions), so a card that allows `app/test/` while forbidding the
    controlled docs either blocks a required edit or invites an unregistered
    one. Only allowed entries rooted at `app/test/` count: a broader `app/**`
    covers tests *possibly*, not necessarily, and rejecting that would refuse
    ordinary feature cards.
    """
    touches_tests = any(pat.startswith("app/test/") for pat in allowed)
    blocks_ledger = any(fnmatch.fnmatch(_LEDGER_PROBE, pat) for pat in forbidden)
    if touches_tests and blocks_ledger:
        return (
            "测试路径与受控文档互斥：allowed 含 app/test/ 而 forbidden 含受控文档。"
            "改用例必然要动台账（D1/D3 双向核对）—— 把 docs/specs/controlled/** "
            "加进 allowed，或去掉 app/test/ 路径"
        )
    return None


def command_plan(args: argparse.Namespace) -> int:
    root = root_path(args.root)
    if args.auto_id and args.batch_id:
        print("--auto-id cannot be combined with an explicit batch id", file=sys.stderr)
        return 2
    generated = args.batch_id is None
    batch_id = args.batch_id or generate_batch_id(root)
    args.batch_id = batch_id
    target = root / batch_id
    card_path = target / "card.yaml"
    if card_path.exists() and not args.force:
        print(f"card already exists: {card_path} (use --force to replace draft)", file=sys.stderr)
        return 1
    if generated:
        print(f"batch id: {batch_id}")

    branch = args.branch or (
        f"process/{args.batch_id}" if args.type == "process" else f"{args.type}/{args.batch_id}"
    )
    code, out, _ = run_git(["rev-parse", args.base])
    base = out if code == 0 and out else args.base
    forbidden = args.forbidden or ([] if args.type == "process" else list(PROCESS_PATTERNS))
    mutex = scope_mutex_error(args.allowed or [], forbidden)
    if mutex:
        print(f"refusing card: {mutex}", file=sys.stderr)
        return 1

    card = {
        "batch": args.batch_id,
        "type": args.type,
        "goal": args.goal,
        "branch": branch,
        "base": base,
        "allowed": args.allowed or [],
        "forbidden": forbidden,
        "acceptance": args.acceptance or [],
        "platforms": args.platforms or [],
        "docs": args.docs,
        "docs_impact": args.docs_impact or args.docs,
        "notes": args.note or [],
        "size_budget": args.size_budget,
    }
    write_card(card_path, card)
    print(f"card draft: {card_path}")
    print("edit goal / allowed / acceptance / forbidden, then: batch approve " + args.batch_id)
    return 0


def command_approve(args: argparse.Namespace) -> int:
    root = root_path(args.root)
    target = root / args.batch_id
    card_path = target / "card.yaml"
    if not card_path.exists():
        print(f"card not found: {card_path}", file=sys.stderr)
        return 1
    try:
        card = read_card(card_path)
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    if not str(card.get("goal") or "").strip():
        print("card.goal is required", file=sys.stderr)
        return 1
    if not card.get("allowed"):
        print("card.allowed is required", file=sys.stderr)
        return 1
    mutex = scope_mutex_error(card.get("allowed") or [], card.get("forbidden") or [])
    if mutex:
        print(f"refusing approval: {mutex}", file=sys.stderr)
        return 1

    digest = card_hash(card)
    via = "chat" if args.chat else "tty"
    if args.chat:
        if not args.confirm:
            print("--chat requires --confirm <hash8>", file=sys.stderr)
            return 2
        if args.confirm != digest[:8]:
            print(
                f"confirmation mismatch: expected {digest[:8]}, got {args.confirm}",
                file=sys.stderr,
            )
            return 1
    else:
        if args.confirm:
            print("--confirm is only valid with --chat", file=sys.stderr)
            return 2
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            print(
                "approval requires an interactive terminal; "
                "for the chat flow use --chat --confirm <hash8>",
                file=sys.stderr,
            )
            return 2
        print(f"Card: {args.batch_id} ({card.get('type')})")
        print(f"Goal: {card.get('goal')}")
        print("Allowed:")
        for item in card.get("allowed") or []:
            print(f"  - {item}")
        print(f"Approval hash: {digest}")
        typed = input(f"Type the first 8 characters ({digest[:8]}) to approve: ").strip()
        if typed != digest[:8]:
            print("hash confirmation does not match; card not approved", file=sys.stderr)
            return 1

    approved = approve_card(card, actor_identity())
    approved["approval"]["via"] = via
    write_card(card_path, approved)
    print(f"approved {args.batch_id} via {via}: {approved['approval']['hash']}")
    return 0


def merged_pr_for_branch(branch: str) -> tuple[int, str]:
    code, out, err = run_gh(
        ["pr", "list", "--head", branch, "--state", "merged", "--json", "number,state", "--limit", "1"]
    )
    if code != 0:
        return 0, err or out
    try:
        rows = json.loads(out or "[]")
    except ValueError:
        return 0, "gh returned invalid JSON"
    if not rows:
        return 0, ""
    return int(rows[0].get("number") or 0), ""


def command_start(args: argparse.Namespace) -> int:
    root = root_path(args.root)
    target = root / args.batch_id
    card_path = target / "card.yaml"
    if not card_path.exists():
        print(f"card not found: {card_path}", file=sys.stderr)
        return 1
    try:
        card = read_card(card_path)
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    approval_error = verify_card(card)
    if approval_error:
        print(approval_error, file=sys.stderr)
        return 1

    branch = str(card.get("branch") or "")
    base = str(card.get("base") or "origin/main")
    if not branch:
        print("card.branch is required", file=sys.stderr)
        return 1

    occupied = active_batch(root)
    if occupied is not None and occupied.resolve() != target.resolve():
        if not args.clear_stale:
            print(
                f"active batch is {occupied.name}; finish it before starting {args.batch_id}",
                file=sys.stderr,
            )
            print("one .batch/active at a time; do not overwrite another agent's batch", file=sys.stderr)
            return 1
        if (occupied / "merge.json").exists():
            print(
                f"active batch {occupied.name} has merge.json; it is not stale",
                file=sys.stderr,
            )
            return 1
        active_state = load_json(occupied / "state.json") or {}
        active_branch = str(active_state.get("branch") or "")
        if not active_branch:
            print(f"active batch {occupied.name} has no branch; refusing to clear", file=sys.stderr)
            return 1
        pr, err = merged_pr_for_branch(active_branch)
        if not pr:
            print(
                f"active branch {active_branch} has no merged PR"
                + (f": {err}" if err else "")
                + "; refusing to clear",
                file=sys.stderr,
            )
            return 1
        print(f"clearing stale active {occupied.name} (PR #{pr} merged)")
        (root / "active").unlink()

    if not args.no_branch:
        if run_git(["remote", "get-url", "origin"])[0] == 0:
            code, out, _ = run_git(
                ["ls-remote", "--heads", "origin", f"refs/heads/{branch}"]
            )
            if code == 0 and out.strip():
                print(
                    f"remote branch already exists: {branch}; another clone may hold this batch",
                    file=sys.stderr,
                )
                return 1

    if not args.no_branch:
        exists = run_git(["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"])[0] == 0
        if exists:
            current = current_branch()
            if current != branch:
                code, out, err = run_git(["switch", branch])
                if code != 0:
                    print(f"error: cannot switch to {branch}: {err or out}", file=sys.stderr)
                    return 3
        else:
            code, out, err = run_git(["switch", "-c", branch, base])
            if code != 0:
                print(f"error: cannot create {branch} from {base}: {err or out}", file=sys.stderr)
                return 3

    state = {
        "batch": args.batch_id,
        "type": card.get("type"),
        "branch": branch,
        "base": base,
        "owner": getpass.getuser(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    target.mkdir(parents=True, exist_ok=True)
    (target / "state.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    scope = {
        "batch": args.batch_id,
        "type": card.get("type"),
        "allowed": card.get("allowed") or [],
        "forbidden": card.get("forbidden") or [],
        "acceptance": card.get("acceptance") or [],
        "platforms": card.get("platforms") or [],
        "docs": card.get("docs"),
    }
    signed = sign_scope(scope, (card.get("approval") or {}).get("by"))
    (target / "scope.json").write_text(
        json.dumps(signed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    active = root / "active"
    try:
        active_value = str(target.relative_to(REPO_ROOT))
    except ValueError:
        active_value = str(target)
    active.parent.mkdir(parents=True, exist_ok=True)
    active.write_text(active_value + "\n", encoding="utf-8")

    print(f"started {args.batch_id}: branch={branch} base={base}")
    print(f"state: {target / 'state.json'}")
    print(f"scope: {target / 'scope.json'}")
    return 0


def command_status(args: argparse.Namespace) -> int:
    root = root_path(args.root)
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
    root = root_path(args.root)
    current_active = active_batch(root)
    rows: list[dict[str, Any]] = []
    if root.is_dir():
        for child in root.iterdir():
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
                        "createdAt": state.get("created_at") or "",
                        "active": current_active is not None
                        and current_active.resolve() == child.resolve(),
                    }
                )
    rows.sort(key=lambda row: (row["createdAt"], row["batch"]), reverse=True)
    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    elif rows:
        for row in rows:
            marker = "*" if row["active"] else " "
            print(f"{marker} {row['batch']}\t{row['type']}\t{row['dir']}")
    else:
        print(f"no batches under {root}")
    return 0
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Batch state and card CLI")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="batch state root")
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser("plan", help="write a draft card.yaml")
    plan.add_argument("batch_id", nargs="?")
    plan.add_argument("--auto-id", action="store_true", help="generate YYYYMMDD-<6 hex>")
    plan.add_argument("--type", required=True)
    plan.add_argument("--goal", default="")
    plan.add_argument("--allowed", action="append", default=[])
    plan.add_argument("--forbidden", action="append", default=[])
    plan.add_argument("--acceptance", action="append", default=[])
    plan.add_argument("--platforms", action="append", default=[])
    plan.add_argument("--docs", default="none")
    plan.add_argument(
        "--docs-impact",
        choices=("none", "living", "controlled"),
        default=None,
        help="docs impact profile: none / living / controlled",
    )
    plan.add_argument(
        "--note",
        action="append",
        default=[],
        help="per-file PR note, repeatable: <path>=<what changed>",
    )
    plan.add_argument("--size-budget", type=int, default=400)
    plan.add_argument("--base", default="origin/main")
    plan.add_argument("--branch")
    plan.add_argument("--force", action="store_true")
    plan.set_defaults(func=command_plan)

    approve = subparsers.add_parser("approve", help="hash-lock a reviewed card")
    approve.add_argument("batch_id")
    approve.add_argument("--chat", action="store_true", help="record a chat-confirmed approval")
    approve.add_argument("--confirm", help="first 8 chars of the card hash, required with --chat")
    approve.set_defaults(func=command_approve)

    start = subparsers.add_parser("start", help="create branch, state and scope")
    start.add_argument("batch_id")
    start.add_argument("--no-branch", action="store_true", help="state only; branch already exists")
    start.add_argument(
        "--clear-stale",
        action="store_true",
        help="clear another active batch only when its PR is merged and merge.json is absent",
    )
    start.set_defaults(func=command_start)

    check = subparsers.add_parser("check", help="scope + format/lint/test/docs + evidence")
    check.add_argument("--batch")
    check.add_argument("--base")
    check.add_argument("--quick", action="store_true", help="scope only; no evidence")
    check.add_argument("--no-tests", action="store_true")
    check.add_argument("--no-format", action="store_true")
    check.add_argument("--pr-body", type=Path)
    check.add_argument("--dry-run", action="store_true")
    check.set_defaults(func=command_check)

    pr = subparsers.add_parser("pr", help="generate + validate PR body, then create")
    pr.add_argument("--batch")
    pr.add_argument("--base")
    pr.add_argument("--body-out", type=Path)
    pr.add_argument("--body-file", type=Path)
    pr.add_argument("--confirm")
    pr.add_argument("--prepare", action="store_true")
    pr.add_argument("--title")
    pr.add_argument("--create", action="store_true")
    pr.set_defaults(func=command_pr)

    merge = subparsers.add_parser("merge", help="merge a PR through the M1 gate")
    merge.add_argument("--pr", type=int, required=True)
    merge.add_argument("--batch")
    merge.add_argument("--dry-run", action="store_true")
    merge.add_argument("--yes", action="store_true")
    merge.set_defaults(func=command_merge)

    status = subparsers.add_parser("status", help="show one batch")
    status.add_argument("--batch")
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
