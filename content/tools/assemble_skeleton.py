"""三轴骨架源 → 单文件 `content/skeleton/pack.json`（`SPEC-PACK-005` 形态）。

用法：
    python content/tools/assemble_skeleton.py           装配并落盘
    python content/tools/assemble_skeleton.py --check    只跑校验，不落盘
    python content/tools/assemble_skeleton.py --out <路径>  改产出位置

## 它补的是哪一处空缺

`skeleton-catalog.md` §六 步骤 4 要求「包级机器校验」、步骤 5 要求体积核算，而
在此之前**没有任何脚本认识 `content/skeleton/`**：三轴源 JSON 有 `--check`（抽取期
校验），但「骨架包」这个产物从来没有生成路径 —— 出口第一项「骨架包可加载」因此
一直挂着。本脚本补的就是这条路径，两个动作：

1. 把三轴源合并成一个包（清单 + 六段，`SPEC-PACK-005`）；
2. **对产物**跑五项包级校验（不是对源）—— 校验对象是 `nodes[]` / `edges[]`
   拼出来的那张图，与客户端 `readPack` 看到的是同一份。

## 五项包级校验（步骤 4）

| # | 校验 | 为什么在这一层做 |
|---|---|---|
| ① | `official_code` 轴内唯一 | 源侧 `extract_*.py --check` 查过一次，但**装配可能漏搬/重搬** —— 查产物才是「包能不能用」 |
| ② | 主父唯一 | 每个非根节点**恰好一条** `main` 父边；零条 = 悬空、两条 = 两个父 |
| ③ | 无环 | 父边成环时 `pathOf` 会无限递归，而 `readPack` **不查**父边环（它只查 `⪯` 环） |
| ④ | 无孤儿 | 父边端点必须在 `nodes[]` 里 |
| ⑤ | 每个 `star` 父链走到轴根 | 断链的精华沉不到骨架顶上，界面表现为「这个节点不在任何轴下」 |

另加两条与源侧同判据的：`id` 全局唯一、派生 `path` 全局唯一（`P-01` `P-07`：
`path` 只算不存，算出来查重）。

## 三处必须知道的口径

- **`catalog_note` 丢弃**：源层专用字段（目录原文的「可授文学、理学学位」之类），
  包体只认 `entity-fields` §2 的字段集。留它就等于往包里塞一个没有字段名的键。
- **`version` 是骨架自身的版本，不是目录版本**：`SPEC-PACK-005` 要求 semver，
  三份目录的 2022 / 2025 拼不出 semver。目录版次逐条记在 `sources[].version`。
  **骨架内容变了就递增本版本**，与目录年份解耦。
- **`kinds` 为空数组**：`ADR-0005` 决策 2「`skeleton` 不走插件」⇒ 它不是四类包之一。
  `Pack._verifyFacts` 只要求「声明了 kind 就有 facts」，空 kinds + 零 facts 合法。

输出前缀用 ASCII `[ok]` / `[fail]`：`✓` / `✗` 不在 GBK 内，Windows 中文控制台
（cp936）`print` 会抛 `UnicodeEncodeError`，而 CI 是 UTF-8 永远测不到。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile

CONTENT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKELETON_DIR = os.path.join(CONTENT_DIR, "skeleton")
PACK_NAME = "pack.json"

AXES = ("discipline", "major", "occupation")

# 轴 → 该轴在看板上给用户看的名字（`supercluster` 节点的 name）
AXIS_NAME = {"discipline": "学科", "major": "专业", "occupation": "职业"}

# 骨架自身的版本。**不是目录版本**：目录版次在 `sources[].version`，见文件头第三条。
SKELETON_VERSION = "1.0.0"

# `entity-fields` §1 要求的清单字段。`kinds` 空、四个 facts 全无 —— 骨架不是四类包。
SIGNATURE = None

_JSON_KWARGS = {"ensure_ascii": False, "sort_keys": True, "indent": 2, "separators": (",", ": ")}


class AssembleError(Exception):
    pass


def _load_axis(axis: str) -> dict:
    path = os.path.join(SKELETON_DIR, f"{axis}.json")
    if not os.path.isfile(path):
        raise AssembleError(f"缺源数据：{path}")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if data.get("axis") != axis:
        raise AssembleError(f"{path} 声明的 axis 是 {data.get('axis')!r}，不是 {axis!r}")
    if not data.get("nodes"):
        raise AssembleError(f"{path} 的 nodes 为空")
    return data


def _pack_node(raw: dict) -> dict:
    """源节点 → 包节点（`entity-fields` §2 字段集）。"""
    return {
        "id": raw["id"],
        "axis": raw["axis"],
        "level_slot": raw["level_slot"],
        "official_code": raw.get("official_code"),
        "name": raw["name"],
        "slug": raw["slug"],
        "scope": raw["scope"],
        "pack_id": raw["pack_id"],
        "status": raw["status"],
        "tags": list(raw.get("tags") or []),
        # `catalog_refs` 是必填数组，源里没有 ⇒ 补空。
        # 骨架节点与「哪份目录」的绑定改由 `sources[].appliesTo.axes` 表达（整条轴）。
        "catalog_refs": [],
    }


def _source_of(axis: str, data: dict, node_ids: list[str]) -> dict:
    catalog = data["catalog"]
    return {
        "id": f"skeleton:{axis}",
        "name": catalog["title"],
        "kind": "catalog",
        "version": catalog["edition"],
        # `appliesTo` 两键必填：`axes` 说整条轴适用，`node_scope` 给实际过滤依据。
        # 这里逐条枚举本轴全部节点 id —— 语义就是「这份目录是本轴每个节点的依据」，
        # 段内 id 高度重复，压缩后增量可忽略，比留空或只填根节点更不容易被读错。
        "appliesTo": {"axes": [axis], "node_scope": node_ids},
    }


def assemble() -> tuple[dict, dict[str, int]]:
    nodes: list[dict] = []
    edges: list[dict] = []
    sources: list[dict] = []
    counts: dict[str, int] = {}

    for axis in AXES:
        data = _load_axis(axis)
        axis_ids: list[str] = []
        for raw in data["nodes"]:
            node = _pack_node(raw)
            nodes.append(node)
            axis_ids.append(node["id"])
            parent_id = raw.get("parent_id") or ""
            if parent_id:
                edges.append(
                    {
                        "type": "parent",
                        "child_id": node["id"],
                        "parent_id": parent_id,
                        "kind": "main",
                    }
                )
        sources.append(_source_of(axis, data, axis_ids))
        counts[axis] = len(axis_ids)

    pack = {
        "plugin_id": "skeleton",
        "name": "Weltuhr 骨架",
        "version": SKELETON_VERSION,
        # 骨架不是四类包（`ADR-0005` 决策 2），所以 kinds 空、四个 facts 全无。
        "kinds": [],
        "namespace": "skeleton",
        "schema_version": 1,
        "skeleton_requires": f">={SKELETON_VERSION}",
        "deps": [],
        "license": "unspecified",
        "author": "weltuhr",
        "origin": "content/skeleton",
        "review_state": "pending",
        "signature": SIGNATURE,
        "axes": list(AXES),
        "nodes": nodes,
        "edges": edges,
        # 骨架节点没有 entry（`SPEC-PACK-005`：`entries` 是稀疏表）⇒ 空数组。
        "entries": [],
        "sources": sources,
        # 骨架没有学习路线、没有配方。两段仍须存在：六段缺一即格式错误。
        "schemes": [],
        "methods": [],
    }
    return pack, counts


def check_pack(pack: dict) -> list[str]:
    """步骤 4 的五项 + `id` 全局唯一 + `path` 全局唯一。返回问题列表（空 = 全绿）。"""
    fails: list[str] = []
    nodes = pack["nodes"]
    edges = pack["edges"]

    # ⓪ id 全局唯一（跨轴：`skeleton:discipline/0101` 与 `skeleton:major/0101` 不同，
     #   但它们都以 `skeleton:` 开头，同名同码必须靠轴段区分）
    ids = [n["id"] for n in nodes]
    if len(ids) != len(set(ids)):
        dup = sorted({i for i in ids if ids.count(i) > 1})
        fails.append("id 全局不唯一：" + str(dup[:5]))

    by_id = {n["id"]: n for n in nodes}

    # ① official_code 轴内唯一（空码的轴根不参与）
    for axis in AXES:
        codes = [n["official_code"] for n in nodes if n["axis"] == axis and n["official_code"]]
        if len(codes) != len(set(codes)):
            dup = sorted({c for c in codes if codes.count(c) > 1})
            fails.append(f"official_code 轴内不唯一（{axis}）：{dup[:5]}")

    # ② 主父唯一 + ④ 无孤儿（一次遍历父边）
    parents: dict[str, list[str]] = {nid: [] for nid in by_id}
    for edge in edges:
        if edge["type"] != "parent":
            continue
        child, parent = edge["child_id"], edge["parent_id"]
        if child not in by_id:
            fails.append(f"父边端点不在 nodes：child={child}")
            continue
        if parent not in by_id:
            fails.append(f"孤儿：{child} -> {parent}")
            continue
        if edge["kind"] != "main":
            continue
        parents[child].append(parent)

    for node in nodes:
        got = parents[node["id"]]
        is_root = node["level_slot"] == "supercluster"
        if is_root and got:
            fails.append(f"轴根不该有父边：{node['id']} -> {got}")
        elif not is_root and len(got) != 1:
            fails.append(f"主父不唯一 / 缺失：{node['id']} 有 {len(got)} 条 main 父边")

    # ③ 无环 + ⑤ 每个 star 的父链走到轴根 + path 全局唯一（`P-01` `P-07`）
    paths: dict[str, str] = {}

    def path_of(node_id: str, guard: frozenset[str]) -> str:
        if node_id in paths:
            return paths[node_id]
        node = by_id[node_id]
        if not parents[node_id]:
            paths[node_id] = node["slug"]
            return paths[node_id]
        if node_id in guard:
            fails.append(f"父边有环：{node_id}")
            paths[node_id] = node["slug"]
            return paths[node_id]
        paths[node_id] = path_of(parents[node_id][0], guard | {node_id}) + "/" + node["slug"]
        return paths[node_id]

    for node in nodes:
        path_of(node["id"], frozenset())

    for node in nodes:
        if node["level_slot"] != "star":
            continue
        cur = node["id"]
        depth = 0
        while parents[cur]:
            cur = parents[cur][0]
            depth += 1
            if depth > 8:
                fails.append(f"父链过深：{node['id']}")
                break
        else:
            if by_id[cur]["level_slot"] != "supercluster":
                fails.append(f"star 父链未到轴根：{node['id']}")

    seen: dict[str, list[str]] = {}
    for node in nodes:
        seen.setdefault(paths[node["id"]], []).append(node["id"])
    clashes = {p: v for p, v in seen.items() if len(v) > 1}
    if clashes:
        fails.append("path 全局重复：" + str(list(clashes.items())[:3]))

    return fails


def write_pack(out: str | None = None) -> tuple[str, dict[str, int]]:
    pack, counts = assemble()
    fails = check_pack(pack)
    if fails:
        raise AssembleError("包级校验未通过（%d 条）：\n  %s" % (len(fails), "\n  ".join(fails)))

    text = json.dumps(pack, **_JSON_KWARGS) + "\n"
    out = out or os.path.join(SKELETON_DIR, PACK_NAME)
    # 先写临时文件再改名：中途失败不留半截 pack.json（与 `build.py` 同法）。
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(out), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(tmp, out)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return out, counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="三轴骨架源装配成单文件 pack.json")
    parser.add_argument("--check", action="store_true", help="只跑校验，不落盘")
    parser.add_argument("--out", help="产出路径，默认 content/skeleton/pack.json")
    args = parser.parse_args(argv)

    try:
        if args.check:
            pack, counts = assemble()
            fails = check_pack(pack)
            if fails:
                print("[fail] 包级校验 %d 条：" % len(fails), file=sys.stderr)
                for line in fails:
                    print("  " + line, file=sys.stderr)
                return 1
            total = sum(counts.values())
            print(f"[ok] 校验通过：节点 {total} · 父边 {len(pack['edges'])} · 源 {len(pack['sources'])}")
            print("     " + " · ".join(f"{ax} {counts[ax]}" for ax in AXES))
            return 0

        out, counts = write_pack(args.out)
        total = sum(counts.values())
        print(f"[ok] 写入 {os.path.relpath(out)}")
        print(f"     节点 {total} · 父边 {total - len(AXES)} · 源 {len(AXES)}")
        print("     " + " · ".join(f"{ax} {counts[ax]}" for ax in AXES))
        print(f"     字节 {os.path.getsize(out)}")
        return 0
    except AssembleError as exc:
        print(f"[fail] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
