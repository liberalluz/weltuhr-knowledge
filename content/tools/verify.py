"""校验源数据或已构建的 pack.json；`--suite` 跑 fixtures 回归。

用法：
    python tools/verify.py --root content/tools/fixtures/valid-min
    python tools/verify.py --pack content/python/dist/pack.json
    python tools/verify.py --suite            跑全部 fixtures + 错误码覆盖自检

`--suite` 跑四层，缺一层都不算过：

1. **源数据层**（`fixtures/<name>/`）：走 `build.build_text`，即 `load_source` →
   `validate` → `check_pack_object` 的完整链路。负例各自锁定一种「必须拒绝」的形态。
2. **产物层**（`fixtures/pack/<name>/`）：直接递一个坏 `pack.json` 给
   `check_pack_object`。这一层的错误码在源数据路径上**永远走不到**
   （`assemble()` 拼出的 pack 结构恒定），只能这样测。
3. **覆盖自检**：把 `validator.py` 里定义的全部错误码与 fixtures 断言过的码对账。
   新增规则而没配 fixture，这里会红 —— 这是 `R-07` 的根治，不是补一次就完。
4. **输出可移植性**：扫 `tools/*.py` 的运行期字符串字面量，凡在 GBK 里编码不了
   的字符都报。这一层存在的理由与前三层不同 —— 它守的是**当前环境测不到**的失败：
   前三层的判据都要真的跑一遍才算数，而「print 一个 cp936 编不了的字符」在
   UTF-8 环境（含 CI 的 ubuntu）**永远跑不出来**，只能静态查。
"""

from __future__ import annotations

import argparse
import ast
import glob
import json
import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build  # noqa: E402
import validator  # noqa: E402

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
FIXTURES_DIR = os.path.join(TOOLS_DIR, "fixtures")
EXPECT_NAME = "expect.json"
# 产物层 fixture 与源数据层共用 `fixtures/`，但形态不同（一个 pack.json 而非五段），
# 所以源层遍历必须显式跳过它，否则会把它当成一个坏 fixture。
PACK_DIR_NAME = "pack"
PACK_FIXTURES_DIR = os.path.join(FIXTURES_DIR, PACK_DIR_NAME)


def verify_root(root: str) -> list[validator.Issue]:
    manifest, segments, issues = validator.load_source(root)
    if manifest is not None:
        issues.extend(validator.validate(manifest, segments))
    return sorted(issues, key=lambda i: (i.code, i.where, i.msg))


def _check_pack_file(path: str, expected_version: str | None = None) -> list[validator.Issue]:
    with open(path, encoding="utf-8") as f:
        pack = json.load(f)
    if not isinstance(pack, dict):
        return [validator.Issue("E-PACK-TYPE", "pack.json", "顶层必须是 object")]
    return validator.check_pack_object(pack, expected_version=expected_version)


def verify_pack(path: str) -> list[validator.Issue]:
    return _check_pack_file(path)


# --- fixtures -------------------------------------------------------------


def _materialize(fixture_dir: str, base: str | None, drop: list[str] | None = None) -> str:
    """把 fixture 展开到临时目录：先铺 base，再用自身文件覆盖，最后按 `drop` 删除。

    fixture 只写「与被测规则相关的那个文件」，其余继承 `valid-min`，
    所以 `expect.json` 里必须显式写 `base`，不靠目录名猜。

    `drop` 用于测「缺文件」类判据（`E-MANIFEST-MISSING` / `E-SEGMENT-MISSING`）：
    只靠复制造不出「文件不存在」，必须显式声明删哪个。删在最后一步，
    所以 base 提供的文件也能删。
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

    for name in drop or ():
        target = os.path.join(tmpdir, name)
        if os.path.isdir(target):
            shutil.rmtree(target)
        elif os.path.isfile(target):
            os.remove(target)
        else:
            raise SystemExit(f"fixture 的 drop 项不存在，删不掉：{name}（{fixture_dir}）")
    return tmpdir


def run_fixture(fixture_dir: str) -> list[str]:
    """返回失败说明列表，空 = 该 fixture 行为符合预期。"""
    name = os.path.basename(fixture_dir)
    expect_path = os.path.join(fixture_dir, EXPECT_NAME)
    if not os.path.isfile(expect_path):
        return [f"{name}: 缺 {EXPECT_NAME}"]
    with open(expect_path, encoding="utf-8") as f:
        expect = json.load(f)

    root = _materialize(fixture_dir, expect.get("base"), expect.get("drop"))
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
        if os.path.isdir(os.path.join(FIXTURES_DIR, d)) and d != PACK_DIR_NAME
    )
    failures: list[str] = []
    passed = 0
    for fixture_dir in dirs:
        problems = run_fixture(fixture_dir)
        label = os.path.basename(fixture_dir)
        if problems:
            failures.extend(problems)
            print(f"[fail] {label}")
            for problem in problems:
                print(f"    {problem}")
        else:
            passed += 1
            print(f"[ok] {label}")

    print(f"\n{passed}/{len(dirs)} fixture 通过")
    return 1 if failures else 0


# --- 产物层 fixtures -------------------------------------------------------


def run_pack_fixture(fixture_dir: str) -> list[str]:
    """产物层 fixture：目录内一个 `pack.json` + `expect.json`。

    `expect.json` 用 `codes` 断言必须出现的错误码，用 `expectedVersion` 模拟
    「源 manifest 的版本」以触发 `E-META-VERSION`。这一层不跑 `build`，
    因为被测的就是「构建之后、产物被改坏 / 构建逻辑退化」时的兜底。
    """
    name = os.path.basename(fixture_dir)
    expect_path = os.path.join(fixture_dir, EXPECT_NAME)
    pack_path = os.path.join(fixture_dir, "pack.json")
    if not os.path.isfile(expect_path):
        return [f"{name}: 缺 {EXPECT_NAME}"]
    if not os.path.isfile(pack_path):
        return [f"{name}: 缺 pack.json"]

    with open(expect_path, encoding="utf-8") as f:
        expect = json.load(f)
    try:
        issues = _check_pack_file(pack_path, expect.get("expectedVersion"))
    except json.JSONDecodeError as exc:
        return [f"{name}: pack.json 解析失败：{exc}"]

    found = {i.code for i in issues}
    lacking = [c for c in expect.get("codes", []) if c not in found]
    if lacking:
        return [f"{name}: 期望错误码 {lacking}，实际只报 {sorted(found) or '无'}"]
    if expect.get("exit", 1) == 0 and issues:
        return [f"{name}: 期望通过，实际 {len(issues)} 处失败：{issues[0]}"]
    return []


def run_pack_suite() -> int:
    if not os.path.isdir(PACK_FIXTURES_DIR):
        print(f"找不到 {PACK_FIXTURES_DIR}", file=sys.stderr)
        return 2
    dirs = sorted(
        os.path.join(PACK_FIXTURES_DIR, d)
        for d in os.listdir(PACK_FIXTURES_DIR)
        if os.path.isdir(os.path.join(PACK_FIXTURES_DIR, d))
    )
    failures: list[str] = []
    passed = 0
    for fixture_dir in dirs:
        problems = run_pack_fixture(fixture_dir)
        label = os.path.basename(fixture_dir)
        if problems:
            failures.extend(problems)
            print(f"[fail] {label}")
            for problem in problems:
                print(f"    {problem}")
        else:
            passed += 1
            print(f"[ok] {label}")
    print(f"\n{passed}/{len(dirs)} 产物层 fixture 通过")
    return 1 if failures else 0


# --- 错误码覆盖自检 --------------------------------------------------------

# 只认「真正定义了一处报错」的位置：`_issue("E-...")` 与 `Issue("E-...")`。
# 不用裸正则扫 `E-[A-Z-]+`，否则注释和 docstring 里提到的码会被算进定义集。
CODE_DEF_RE = re.compile(r'(?:_issue|Issue)\(\s*"(E-[A-Z][A-Z0-9-]+)"')


def defined_codes() -> set[str]:
    codes: set[str] = set()
    for fname in ("validator.py", "verify.py"):
        with open(os.path.join(TOOLS_DIR, fname), encoding="utf-8") as f:
            codes |= set(CODE_DEF_RE.findall(f.read()))
    return codes


def asserted_codes() -> set[str]:
    codes: set[str] = set()
    patterns = (
        os.path.join(FIXTURES_DIR, "*", EXPECT_NAME),
        os.path.join(PACK_FIXTURES_DIR, "*", EXPECT_NAME),
    )
    for pattern in patterns:
        for path in glob.glob(pattern):
            with open(path, encoding="utf-8") as f:
                codes |= set(json.load(f).get("codes") or [])
    return codes


def coverage_report() -> int:
    """定义集 vs 断言集。两边差任何一个都算失败。

    缺断言 = 那条规则从没被执行过（`R-07` 的形态）；
    断言了未定义的码 = expect 里写了个 typo，永远不可能满足。
    """
    defined = defined_codes()
    asserted = asserted_codes()
    gaps = sorted(defined - asserted)
    unknown = sorted(asserted - defined)

    print(f"错误码覆盖：{len(defined) - len(gaps)}/{len(defined)}")
    status = 0
    if gaps:
        print("  以下错误码没有任何 fixture 断言（新增规则须同步加负例）：")
        for code in gaps:
            print(f"    - {code}")
        status = 1
    if unknown:
        print(f"  以下错误码被 expect 断言但 validator 未定义（疑似笔误）：{unknown}")
        status = 1
    return status


# --- 输出可移植性自检 ------------------------------------------------------

# 这一层守的失败**在当前环境测不到**：`print` 一个 cp936 编码不了的字符，在 UTF-8
# 环境（CI 是 ubuntu）永远不触发 —— 全绿也不代表没问题。只能静态查。
#
# 只查 AST 里的字符串字面量：注释不进 AST（本来也不会被打印），模块 / 类 / 函数的
# docstring 显式跳过（不参与 output）。判据用 GBK 而非 ASCII —— 中文输出是本项目
# 的常态，按 ASCII 判会把每个汉字都算成违规。
OUTPUT_ENCODING = "gbk"


def _printable(text: str) -> str:
    """把编不了的字符转成 `\\uXXXX` 转义。

    **报错信息自己必须能打出来。** 否则报 `✓` 违规的那一行本身就含 `✓`，
    在同一个控制台上再崩一次 —— 把「诊断」变成「二次事故」。
    """
    out: list[str] = []
    for ch in text:
        try:
            ch.encode(OUTPUT_ENCODING)
        except UnicodeEncodeError:
            out.append(f"\\u{ord(ch):04x}")
        else:
            out.append(ch)
    return "".join(out)


def _docstring_ids(tree: ast.AST) -> set[int]:
    owners = (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)
    ids: set[int] = set()
    for node in ast.walk(tree):
        if not isinstance(node, owners):
            continue
        body = node.body
        if not body or not isinstance(body[0], ast.Expr):
            continue
        value = body[0].value
        if isinstance(value, ast.Constant) and isinstance(value.value, str):
            ids.add(id(value))
    return ids


def unportable_literals(path: str) -> list[str]:
    """该文件里「运行期会输出、但 OUTPUT_ENCODING 编不了」的字面量。"""
    with open(path, encoding="utf-8") as f:
        try:
            tree = ast.parse(f.read(), filename=path)
        except SyntaxError as exc:
            return [f"L{exc.lineno} 语法错误，无法自检：{exc.msg}"]

    skip = _docstring_ids(tree)
    problems: list[str] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Constant) or not isinstance(node.value, str):
            continue
        if id(node) in skip:
            continue
        try:
            node.value.encode(OUTPUT_ENCODING)
        except UnicodeEncodeError:
            snippet = node.value.strip().replace("\n", " ")[:40]
            problems.append(f"L{node.lineno} {_printable(snippet)!r}")
    return problems


def portability_report() -> int:
    files = sorted(glob.glob(os.path.join(TOOLS_DIR, "*.py")))
    problems = [
        f"{os.path.basename(path)}: {problem}"
        for path in files
        for problem in unportable_literals(path)
    ]
    print(f"输出可移植性：{len(files)} 个脚本的运行期字面量须可用 {OUTPUT_ENCODING} 编码")
    if not problems:
        print(f"  {len(files)} 个脚本无风险字符")
        return 0
    print("  以下字面量在中文 Windows 控制台（cp936）print 时会抛 UnicodeEncodeError：")
    for problem in problems:
        print(f"    - {problem}")
    print("  改用 ASCII 前缀（如 `[ok]` / `[fail]`）；注释与 docstring 不查，字符可留在那里。")
    return 1


def run_all() -> int:
    status = 0
    print("— 源数据层 —")
    if run_suite() != 0:
        status = 1
    print("\n— 产物层 —")
    if run_pack_suite() != 0:
        status = 1
    print("\n— 错误码覆盖 —")
    if coverage_report() != 0:
        status = 1
    print("\n— 输出可移植性 —")
    if portability_report() != 0:
        status = 1
    return status


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="校验 pack 源数据或产出")
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--root", help="源目录")
    target.add_argument("--pack", help="已构建的 pack.json")
    target.add_argument(
        "--suite",
        action="store_true",
        help="跑全部 fixtures（源数据层 + 产物层）+ 错误码覆盖 + 输出可移植性自检",
    )
    args = parser.parse_args(argv)

    if args.suite:
        return run_all()

    issues = verify_root(args.root) if args.root else verify_pack(args.pack)
    if issues:
        print(f"{len(issues)} 处校验失败")
        for issue in issues:
            print(f"  {issue}")
        return 1

    print("[ok] 校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
