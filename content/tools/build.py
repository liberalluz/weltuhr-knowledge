"""空间源数据 → `dist/pack.json`。

用法：
    python tools/build.py                 构建 content/ 下全部空间
    python tools/build.py <空间 id>        只构建单个空间
    python tools/build.py --root <目录>    构建指定目录（fixtures 用）
    python tools/build.py --check          两遍构建 + 不同环境复跑，比 sha256

设计约束（**本脚本实现的是作废的五段形态**；目标形态是「单文件 = 清单 + 六段」，
见 `SPEC-PACK-005` 及其「迁移状态」段 —— 管线随三包重建一并迁）：
  - `meta.version` **原样透传** `manifest.json` 的 `version`，绝不改写
  - `meta` 是**信封**不是内容段：只含 `space` 与 `version`，**不含构建时间戳**
  - 序列化参数硬编码在此：`sort_keys` + 固定缩进 + `ensure_ascii=False` +
    末尾单换行。换任何一项都会让同一 commit 的两次构建 byte 不等
  - **输出前缀用 ASCII `[ok]` / `[fail]`**：`✓`(U+2713) / `✗`(U+2717) 不在 GBK 内，
    Windows 中文控制台（cp936）`print` 时会抛 `UnicodeEncodeError`。而这一步
    **在 UTF-8 环境（CI 是 ubuntu）永远不触发**，所以绿灯不能证明它没问题。
    `verify.py --suite` 的「输出可移植性」一步专门拦这类字符
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import validator  # noqa: E402

CONTENT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK_NAME = "pack.json"

# 唯一事实源：`manifest.json` 的 `version`，此处不改写、不注释、不格式化。
# 透传一旦被"优化"（str() / strip / 重整），tag 名就对不上产出，而 dist/ 不入库、
# tag 是唯一指针，事后无从比对。
_JSON_KWARGS = {"ensure_ascii": False, "sort_keys": True, "indent": 2, "separators": (",", ": ")}


class BuildError(Exception):
    pass


def assemble(root: str) -> tuple[dict, list[validator.Issue]]:
    """读源并拼出 pack 对象。校验不通过时返回 issues，由调用方决定是否落盘。"""
    manifest, segments, issues = validator.load_source(root)
    if manifest is None:
        return {}, issues

    issues.extend(validator.validate(manifest, segments))

    pack = {
        "meta": {"space": manifest.get("id"), "version": manifest.get("version")},
    }
    for name in validator.SEGMENTS:
        pack[name] = segments.get(name) or []

    return pack, issues


def serialize(pack: dict) -> str:
    """固定序列化。末尾单换行 —— 少了会让某些 diff 工具提示 "no newline"。"""
    return json.dumps(pack, **_JSON_KWARGS) + "\n"


def build_text(root: str) -> tuple[str, list[validator.Issue]]:
    pack, issues = assemble(root)
    if issues:
        return "", issues
    # 产出层再守一次：段没多没错、meta.version 与源逐字一致
    manifest_path = os.path.join(root, "manifest.json")
    with open(manifest_path, encoding="utf-8") as f:
        expected = json.load(f).get("version")
    issues = validator.check_pack_object(pack, expected_version=expected)
    if issues:
        return "", issues
    return serialize(pack), []


def build(root: str, out: str | None = None) -> str:
    text, issues = build_text(root)
    if issues:
        raise BuildError(_format_issues(root, issues))

    out = out or os.path.join(root, "dist", PACK_NAME)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    # 先写临时文件再改名：中途失败不会留下半截 pack.json
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(out), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(tmp, out)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return out


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _reorder_keys(value):
    """递归反转每个 object 的键顺序，用于证明序列化不依赖源文件的书写顺序。

    只做反转而不随机打乱：确定、可复现，且 ≥2 个键时必然改变顺序。
    """
    if isinstance(value, dict):
        return {k: _reorder_keys(v) for k, v in reversed(list(value.items()))}
    if isinstance(value, list):
        return [_reorder_keys(v) for v in value]
    return value


def check_determinism(root: str) -> list[str]:
    """确定性四项实证。返回失败原因列表，空 = 通过。

    1. 同进程两次构建 byte 相同
    2. 解析产出后再序列化，与原文 byte 相同（幂等）
    3. **键顺序打乱后**再序列化，仍与原文 byte 相同（`sort_keys` 确实生效）
    4. **另一个进程 + 不同 PYTHONHASHSEED + 不同 cwd** 构建，byte 相同
    """
    problems: list[str] = []

    first, issues = build_text(root)
    if issues:
        return [f"源数据校验未通过，无法验证确定性：{i}" for i in issues]

    second, _ = build_text(root)
    if first != second:
        problems.append("同进程两次构建产出不同")

    reparsed = serialize(json.loads(first))
    if reparsed != first:
        problems.append("产出再序列化后 byte 不同（序列化不幂等）")

    # 若 sort_keys 被去掉，源文件的书写顺序会渗进产出：交换字段顺序即 byte 不同
    reordered = serialize(_reorder_keys(json.loads(first)))
    if reordered != first:
        problems.append("产出依赖键的书写顺序（`sort_keys=True` 未生效）")

    with tempfile.TemporaryDirectory() as tmpdir:
        out = os.path.join(tmpdir, PACK_NAME)
        env = dict(os.environ)
        # 值必须与父进程不同，否则测不到「遍历顺序依赖哈希种子」这类问题
        env["PYTHONHASHSEED"] = str(int.from_bytes(os.urandom(2), "big") + 1)
        # 子进程输出恒 UTF-8。父侧按 utf-8 解码，若子进程用系统代码页（中文 Windows 为
        # cp936）写中文，解码会在 CPython 的 `_readerthread` 后台线程里失败 —— 那个
        # `UnicodeDecodeError` 死在子线程、主线程收不到，`proc.stderr` 会**静默变成
        # None**，于是 `.strip()` 抛 `AttributeError`，把「子进程为什么挂」彻底埋掉。
        #
        # `PYTHONIOENCODING` 的优先级**高于** `PYTHONUTF8`：父进程若带着它，子进程会
        # 仍按旧代码页写字节。所以必须显式摘掉，只留 PYTHONUTF8。
        env.pop("PYTHONIOENCODING", None)
        env["PYTHONUTF8"] = "1"
        proc = subprocess.run(
            [sys.executable, os.path.abspath(__file__), "--root", os.path.abspath(root), "--out", out],
            cwd=tmpdir,
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            # 兜底：子进程被信号杀掉等情况下仍可能写出非 UTF-8 字节，替换掉而不是抛。
            errors="replace",
        )
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or "").strip()
            problems.append(f"子进程构建失败：{detail or '（子进程无输出）'}")
        else:
            with open(out, "rb") as f:
                third = f.read()
            if third != first.encode("utf-8"):
                problems.append("不同 PYTHONHASHSEED / cwd 下构建产出不同")

    return problems


def _format_issues(root: str, issues: list[validator.Issue]) -> str:
    lines = [f"{root}：{len(issues)} 处校验失败"]
    lines.extend(f"  {i}" for i in issues)
    return "\n".join(lines)


def _display_path(path: str) -> str:
    """相对 CONTENT_DIR 显示；跨盘（Windows 上 --out 指到别的盘）时退回绝对路径。"""
    try:
        return os.path.relpath(path)
    except ValueError:
        return path


def discover_spaces(content_dir: str) -> list[str]:
    """`content/` 下含 manifest.json 的目录即空间；`tools/` 天然不含，无需排除。"""
    found = []
    for name in sorted(os.listdir(content_dir)):
        path = os.path.join(content_dir, name)
        if os.path.isdir(path) and os.path.isfile(os.path.join(path, "manifest.json")):
            found.append(path)
    return found


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="构建 content 空间包")
    parser.add_argument("space", nargs="?", help="空间 id（content/ 下的目录名）")
    parser.add_argument("--root", help="直接指定源目录（优先于 <空间>）")
    parser.add_argument("--out", help="产出路径，默认 <源目录>/dist/pack.json")
    parser.add_argument("--check", action="store_true", help="只验确定性，不落盘")
    args = parser.parse_args(argv)

    if args.root:
        roots = [args.root]
    elif args.space:
        roots = [os.path.join(CONTENT_DIR, args.space)]
        if not os.path.isdir(roots[0]):
            print(f"找不到空间目录：{roots[0]}", file=sys.stderr)
            return 2
    else:
        roots = discover_spaces(CONTENT_DIR)
        if not roots:
            print(
                f"{CONTENT_DIR} 下没有任何空间（需要含 manifest.json 的目录）。\n"
                "首个空间落地前，可用 `--root content/tools/fixtures/valid-min` 验证管线。",
                file=sys.stderr,
            )
            return 2

    status = 0
    for root in roots:
        label = os.path.basename(os.path.normpath(root))
        if args.check:
            problems = check_determinism(root)
            if problems:
                status = 1
                print(f"[fail] {label} 确定性检查未通过")
                for problem in problems:
                    print(f"    {problem}")
            else:
                first, _ = build_text(root)
                print(f"[ok] {label} 确定性检查通过（sha256 {hashlib.sha256(first.encode()).hexdigest()[:12]}）")
            continue

        try:
            out = build(root, args.out)
        except BuildError as exc:
            status = 1
            print(f"[fail] {exc}", file=sys.stderr)
            continue
        print(f"[ok] {label} → {_display_path(out)}（sha256 {sha256(out)[:12]}）")

    return status


if __name__ == "__main__":
    sys.exit(main())
