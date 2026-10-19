#!/usr/bin/env python3
"""CI 改动面判据：这笔改动要不要跑某个 workflow 的检查。

用法（在 `app/` 下）：
    python3 tool/ci/affected.py --scope app --base <sha>
    python3 tool/ci/affected.py --self-test
    python3 tool/ci/affected.py --list

**stdout 恰好一行** `run=true` / `run=false`，可以直接
`>> "$GITHUB_OUTPUT"`；诊断走 stderr，不污染取值。

判据表在 `scopes.json`，只由**依赖关系**决定，不随开发阶段调整：

- `app` 含 `content/` —— `app-checks` 要现场构建
  `content/<空间>/dist/pack.json` 喂读包测试（`dist/` 不入库，`SPEC-PACK-018`）。
  不含的话，「内容端改结构、客户端读包逻辑坏了」这类 PR 会全绿。
- `content` 含 `app/tool/ci/` —— 判据自身改动要触发一次回归，否则判据改坏了没人知道。
- `app` 含 `docs/deliverables/` —— `tool/docs/check.dart` 对的就是那四份交付物的
  版号与读数。不含的话，一笔「只改 `docs/`」的 PR 会跳过口径对账 —— 而那正是
  四份文档每版都在改、也是最该被机器看住的地方。
- 两条都含各自的 workflow 文件。

为什么不写 workflow 级 `paths:`（这是本文件存在的理由）：
`paths` 未命中时整个 workflow **不运行**，check 也就**不产生结论**。分支保护一旦
把它设成 required，只改 `docs/` 的 PR 会永远停在
"Expected - Waiting for status to be reported"，合不了。所以 workflow 不设 `paths`，
job 常驻，由本脚本判断后按 step 跳过 —— check 每次都回报 success。

两种「宁可跑」的缺省，都不是保守主义，而是**不能判断**：
- 改动面为空：diff 可能算错（`base` 就是 `HEAD`、clone 深度不够），不能据此跳过。
- `base` 不可用（空 / 全 `0`，如新分支首次推送）：无法算增量，只能全跑。
"""

import argparse
import json
import os
import subprocess
import sys

ZERO_SHA = "0" * 40
_SCOPES_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scopes.json")


# ---------------------------------------------------------------------------
# 判据（纯函数，不碰 IO —— `--self-test` 直接拿它测）
# ---------------------------------------------------------------------------


def load_scopes(path=_SCOPES_PATH):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)["scopes"]


def normalize(path):
    """统一成仓库相对的正斜杠路径，窗台的 `\\` 与 `./` 前缀都归一。"""
    p = (path or "").strip().replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]
    return p.lstrip("/")


def hits(prefix, path):
    """目录前缀按 `startswith` 匹配，精确路径按相等匹配。"""
    return path.startswith(prefix) if prefix.endswith("/") else path == prefix


def affected(inputs, changed):
    """改动面是否影响该作用域。

    空改动面返回 `True` —— 见模块文档：那是「判断不了」，不是「没有改动」。
    """
    if not changed:
        return True
    for raw in changed:
        path = normalize(raw)
        for prefix in inputs:
            if hits(prefix, path):
                return True
    return False


def first_hit(inputs, changed):
    """返回 `(前缀, 文件)`，用于把「为什么跑」写进日志；未命中返回 `None`。"""
    for raw in changed:
        path = normalize(raw)
        for prefix in inputs:
            if hits(prefix, path):
                return prefix, path
    return None


def usable_base(base):
    """`base` 是否可用于算增量。

    全 `0` 是 GitHub 在「新分支首次推送」时给的占位值；空串来自
    `pull_request` 事件里没有 `before` 字段的取值表达式。
    """
    if not base:
        return False
    b = base.strip()
    return bool(b) and set(b) != {"0"}


# ---------------------------------------------------------------------------
# IO
# ---------------------------------------------------------------------------


def changed_files(root, base):
    """`base...HEAD` 三点 diff 的文件列表。

    三点而非两点：语义是「从 merge-base 起算的本次改动」，不会把 base 分支上
    别人的提交算进来。`--no-renames` 让重命名拆成删 + 增两条，避免
    `{old => new}` 这类输出被当成单一路径。

    返回 `(files, None)` 或 `(None, 原因)`。失败由调用方降级成「全跑」。
    """
    try:
        r = subprocess.run(
            ["git", "diff", "--name-only", "--no-renames", "{0}...HEAD".format(base)],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            errors="replace",
        )
    except OSError as exc:
        return None, "git 无法执行：{0}".format(exc)
    if r.returncode != 0:
        # 解码失败时 `stderr` 可能是 `None`，不能直接 `.strip()`。
        lines = [ln for ln in (r.stderr or "").strip().splitlines() if ln.strip()]
        # git 遇到非法 revision 会打一屏 usage，`fatal:` 那行才是原因。
        fatal = [ln for ln in lines if "fatal:" in ln]
        if fatal:
            return None, fatal[0]
        return None, lines[0] if lines else "git diff 退出码 {0}".format(r.returncode)
    return [ln for ln in (r.stdout or "").splitlines() if ln.strip()], None


# ---------------------------------------------------------------------------
# 自检
# ---------------------------------------------------------------------------


def self_test(scopes):
    cases = [
        ("app", ["app/lib/main.dart"], True, "客户端源码"),
        ("app", ["content/python/manifest.json"], True, "内容数据变了要重跑读包测试"),
        ("app", ["content/tools/build.py"], True, "内容构建脚本"),
        ("app", ["app/tool/ci/affected.py"], True, "判据自身在 app/ 下"),
        ("app", ["docs/deliverables/04-test/STD-软件测试说明.md"], True,
         "交付物口径由 tool/docs 对账，改了就重跑"),
        ("app", ["docs/guides/git-conventions.md"], False, "指南不参与任何检查"),
        ("app", [".github/workflows/app-checks.yml"], True, "自身 workflow"),
        (
            "app",
            [".github/workflows/content-checks.yml"],
            False,
            "别的 workflow 不互相牵连",
        ),
        ("app", [], True, "空改动面判不了，按跑处理"),
        ("content", ["app/lib/main.dart"], False, "客户端改动不收进内容面"),
        ("content", ["content/tools/build.py"], True, "内容脚本"),
        ("content", ["app/tool/ci/affected.py"], True, "判据改动触发一次回归"),
        ("content", ["docs/guides/environment.md"], False, "文档不触发"),
    ]

    failed = 0
    for scope, changed, want, why in cases:
        inputs = scopes.get(scope)
        if inputs is None:
            stderr_write("[ci:self-test] 未知 scope：{0}".format(scope))
            failed += 1
            continue
        got = affected(inputs, changed)
        if got != want:
            stderr_write(
                "[ci:self-test] 失败 · scope={0} · 期望 {1} 实得 {2} · {3} · {4}".format(
                    scope, want, got, why, changed or ["(空)"]
                )
            )
            failed += 1

    if failed:
        stderr_write("[ci:self-test] {0} 条失败".format(failed))
        return 1
    stdout_write("[ci:self-test] {0} 条通过".format(len(cases)))
    return 0


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------


def stdout_write(msg):
    sys.stdout.write(msg + "\n")


def stderr_write(msg):
    sys.stderr.write(msg + "\n")


def _make_output_safe():
    """让非 GBK 字符退化而不是抛 `UnicodeEncodeError`。

    窗台终端是 cp936：`errors="replace"` 把它变成 `?`，进程不死、CI（UTF-8）
    也照常。比在每个 print 里挑字符更可靠 —— 漏一个就整条工具链崩。
    """
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(errors="replace")
            except (ValueError, OSError):
                pass


def main(argv=None):
    _make_output_safe()

    parser = argparse.ArgumentParser(
        description="判断这笔改动是否影响某个 CI 作用域（stdout 只输出 run=true|false）"
    )
    parser.add_argument("--scope", help="作用域 id，见 scopes.json")
    parser.add_argument("--base", help="基线 sha；PR 用 base.sha，push 用 event.before")
    parser.add_argument("--root", default="..", help="仓库根（在 app/ 下执行时默认 ..）")
    parser.add_argument("--self-test", action="store_true", help="跑内置断言，不读 git")
    parser.add_argument("--list", action="store_true", help="列出作用域与输入闭包")
    args = parser.parse_args(argv)

    try:
        scopes = load_scopes()
    except (OSError, ValueError, KeyError) as exc:
        stderr_write("[ci] 读不到判据表 scopes.json：{0}".format(exc))
        return 2

    if args.self_test:
        return self_test(scopes)

    if args.list:
        for name in sorted(scopes):
            stdout_write("{0}: {1}".format(name, ", ".join(scopes[name])))
        return 0

    if not args.scope:
        stderr_write("[ci] 缺 --scope")
        return 2
    if args.scope not in scopes:
        # 未知作用域是笔误，不能降级成「跑」，否则 workflow 里改名后静默失效。
        stderr_write(
            "[ci] 未知作用域：{0}（可选：{1}）".format(
                args.scope, ", ".join(sorted(scopes))
            )
        )
        return 2

    inputs = scopes[args.scope]

    if not usable_base(args.base):
        stderr_write(
            "[ci] base 不可用（{0!r}），无法算增量 ⇒ 全跑".format(args.base)
        )
        stdout_write("run=true")
        return 0

    files, err = changed_files(args.root, args.base)
    if files is None:
        stderr_write("[ci] 算不出改动面（{0}）⇒ 全跑".format(err))
        stdout_write("run=true")
        return 0

    run = affected(inputs, files)
    stderr_write(
        "[ci] scope={0} · base={1} · 改动 {2} 个文件".format(
            args.scope, args.base[:12], len(files)
        )
    )
    hit = first_hit(inputs, files)
    if hit is not None:
        stderr_write("[ci] 命中 {0} <- {1}".format(hit[0], hit[1]))
    else:
        stderr_write("[ci] 未命中任何输入（{0}）".format(", ".join(inputs)))

    stdout_write("run={0}".format("true" if run else "false"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
