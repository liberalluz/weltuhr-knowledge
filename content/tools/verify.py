"""校验源数据或已构建的 pack.json；`--suite` 跑 fixtures 回归。

用法：
    python tools/verify.py --root content/tools/fixtures/valid-min
    python tools/verify.py --pack content/python/dist/pack.json
    python tools/verify.py --suite            跑全部 fixtures（含期望失败的负例）

`--suite` 的意义：三个负例各自锁定一种「校验器必须拒绝」的形态。若哪天有人
把某条规则放宽，这里会红；否则负例被删了也没人发现。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build  # noqa: E402
import validator  # noqa: E402

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
FIXTURES_DIR = os.path.join(TOOLS_DIR, "fixtures")
EXPECT_NAME = "expect.json"


def verify_root(root: str) -> list[validator.Issue]:
    manifest, segments, issues = validator.load_source(root)
    if manifest is not None:
        issues.extend(validator.validate(manifest, segments))
    return sorted(issues, key=lambda i: (i.code, i.where, i.msg))


def verify_pack(path: str) -> list[validator.Issue]:
    with open(path, encoding="utf-8") as f:
        pack = json.load(f)
    if not isinstance(pack, dict):
        return [validator.Issue("E-PACK-TYPE", "pack.json", "顶层必须是 object")]
    return validator.check_pack_object(pack)


# --- fixtures -------------------------------------------------------------


def _materialize(fixture_dir: str, base: str | None) -> str:
    """把 fixture 展开到临时目录：先铺 base，再用自身文件覆盖。

    fixture 只写「与被测规则相关的那个文件」，其余继承 `valid-min`，
    所以 `expect.json` 里必须显式写 `base`，不靠目录名猜。
    """
    tmpdir = tempfile.mkdtemp(prefix="pack-fixture-")
    if base:
        base_dir = os.path.join(FIXTURES_DIR, base)
        if not os.path.isdir(base_dir):
            raise SystemExit(f"fixture 的 base 不存在：{base_dir}")
        for name in os.listdir(base_dir):
            if name == EXPECT_NAME:
                continue
            src = os.path.join(base_dir, name)
            dst = os.path.join(tmpdir, name)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

    for name in os.listdir(fixture_dir):
        if name == EXPECT_NAME:
            continue
        src = os.path.join(fixture_dir, name)
        dst = os.path.join(tmpdir, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dst)
    return tmpdir


def run_fixture(fixture_dir: str) -> list[str]:
    """返回失败说明列表，空 = 该 fixture 行为符合预期。"""
    name = os.path.basename(fixture_dir)
    expect_path = os.path.join(fixture_dir, EXPECT_NAME)
    if not os.path.isfile(expect_path):
        return [f"{name}: 缺 {EXPECT_NAME}"]
    with open(expect_path, encoding="utf-8") as f:
        expect = json.load(f)

    root = _materialize(fixture_dir, expect.get("base"))
    try:
        text, issues = build.build_text(root)
        problems: list[str] = []
        want_exit = expect.get("exit", 0)

        if want_exit == 0:
            if issues:
                problems.append(f"期望通过，实际 {len(issues)} 处失败：{issues[0]}")
            elif not text:
                problems.append("期望通过，实际未产出")
        else:
            if not issues:
                problems.append("期望失败，实际通过（校验器漏了这条判据）")
            else:
                found = {i.code for i in issues}
                lacking = [c for c in expect.get("codes", []) if c not in found]
                if lacking:
                    problems.append(f"期望错误码 {lacking}，实际只报 {sorted(found)}")

        # 派生值断言：inversions 必须算得出来，否则 Planner 无法展示代价
        if "inversions" in expect:
            manifest, segments, _ = validator.load_source(root)
            scheme_id = expect.get("scheme")
            schemes = segments.get("schemes") or []
            target = next((s for s in schemes if s.get("id") == scheme_id), None)
            if target is None:
                problems.append(f"找不到 scheme {scheme_id!r}")
            else:
                actual = validator.compute_inversions(target.get("nodes") or [], segments.get("edges") or [])
                if actual != expect["inversions"]:
                    problems.append(f"inversions 期望 {expect['inversions']}，实算 {actual}")

        return [f"{name}: {p}" for p in problems]
    finally:
        shutil.rmtree(root, ignore_errors=True)


def run_suite() -> int:
    if not os.path.isdir(FIXTURES_DIR):
        print(f"找不到 {FIXTURES_DIR}", file=sys.stderr)
        return 2

    dirs = sorted(
        os.path.join(FIXTURES_DIR, d)
        for d in os.listdir(FIXTURES_DIR)
        if os.path.isdir(os.path.join(FIXTURES_DIR, d))
    )
    failures: list[str] = []
    passed = 0
    for fixture_dir in dirs:
        problems = run_fixture(fixture_dir)
        label = os.path.basename(fixture_dir)
        if problems:
            failures.extend(problems)
            print(f"✗ {label}")
            for problem in problems:
                print(f"    {problem}")
        else:
            passed += 1
            print(f"✓ {label}")

    print(f"\n{passed}/{len(dirs)} fixture 通过")
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="校验 pack 源数据或产出")
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--root", help="源目录")
    target.add_argument("--pack", help="已构建的 pack.json")
    target.add_argument("--suite", action="store_true", help="跑 fixtures 回归")
    args = parser.parse_args(argv)

    if args.suite:
        return run_suite()

    issues = verify_root(args.root) if args.root else verify_pack(args.pack)
    if issues:
        print(f"{len(issues)} 处校验失败")
        for issue in issues:
            print(f"  {issue}")
        return 1

    print("✓ 校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
