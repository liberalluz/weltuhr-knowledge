"""跨轴先修边源（`content/terrain/terrain.json`）→ `content/terrain/pack.json`。

用法：
    python content/tools/assemble_terrain.py           装配 terrain 包
    python content/tools/assemble_terrain.py --check   只跑校验，不落盘

**为什么源文件不叫 `manifest.json`**：`build.py` 与 `assemble_pack.py` 都按
「目录内含 `manifest.json`」发现空间。用那个名字，它们会把 terrain 当成载荷
空间去装配，然后在「缺 `items.json`」上失败。名字不同 ⇒ 自动发现跳过它，
四个装配器各装自己那一类包。

与 `assemble_pack.py` 的分工：那个装载荷包（`nodes` / `entries` 有内容），
这个只装边 —— terrain 包**没有节点**，它的边指向**别的包**的节点
（`ADR-0005` 决策 4：先修边跨轴，故独立成第四类包）。

派生口径 —— 与 `payload.counts`、`terrain.edge_counts` 同一条理由：
摘要与正文不一致时，没有任何一处会报错。

| 字段 | 来源 |
|---|---|
| `terrain.edge_counts` | 实扫 `edges[]` 两类强度，不手填 |
| `terrain.axes_covered` | 按端点 id 的包前缀，去已装配的 `pack.json` 查节点 `axis`，去重现算 |

`axes_covered` **不手填**：手填 `["major"]` 也能过 `_checkTerrainAxes`
（它只查 `covered` 是不是 `axes[]` 的子集），但摘要会说这个包只跨一条轴，
而它的边明明跨了两条。这类「校验绿、说的是假话」的字段，一律不让手填。

输入契约（装配期查，不查包内自洽 —— 那是 `validator.py` 与 `pack_reader` 的事）：

- 端点 id 形如 `<plugin>:<local>`，且 `<plugin>` 不是 `terrain` 自己
  （自指的边在装载层图里是一条两端同包的悬空边）
- 端点节点必须在其所属包的 `nodes[]` 里存在
- `strength` 只取 `required` / `recommended`
- 现算出的 `axes_covered` 必须是源 `axes[]` 的子集
- `edges[]` 非空

**依赖已装配的包**：`content/python/pack.json` 与 `content/skeleton/pack.json`。
没装配就报错让人先跑 —— 猜一个轴只会把错误藏起来，而那正是本脚本要防的事。
所以 CI 里它排在 `assemble_pack.py`、`assemble_skeleton.py` **之后**。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile

CONTENT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TERRAIN_DIR = os.path.join(CONTENT_DIR, "terrain")
SOURCE_NAME = "terrain.json"
PACK_NAME = "pack.json"

_JSON_KWARGS = {
    "ensure_ascii": False,
    "sort_keys": True,
    "indent": 2,
    "separators": (",", ": "),
}

STRENGTHS = ("required", "recommended")


class AssembleError(Exception):
    """源数据或输入契约有问题 —— 一律拒装，不产出半成品。"""


def read_json(path: str) -> dict:
    if not os.path.isfile(path):
        raise AssembleError(f"缺 {os.path.relpath(path)}")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def node_axis(pack_id: str, node_id: str, cache: dict[str, dict[str, dict]]) -> str:
    """按端点 id 反查它所属节点的轴。缓存按包，不按节点。"""
    if pack_id not in cache:
        path = os.path.join(CONTENT_DIR, pack_id, PACK_NAME)
        if not os.path.isfile(path):
            raise AssembleError(
                f"端点所属的包还没装配：{os.path.relpath(path)}"
                "（先跑 content/tools/assemble_pack.py，骨架再跑 assemble_skeleton.py）"
            )
        cache[pack_id] = {node["id"]: node for node in read_json(path).get("nodes") or []}
    nodes = cache[pack_id]
    if node_id not in nodes:
        raise AssembleError(f"端点不在 {pack_id} 的 nodes[] 里：{node_id}")
    return nodes[node_id]["axis"]


def assemble(root: str | None = None) -> tuple[dict, dict[str, int]]:
    root = root or TERRAIN_DIR
    source = read_json(os.path.join(root, SOURCE_NAME))

    raw_edges = source.get("edges") or []
    if not raw_edges:
        raise AssembleError("edges[] 为空 —— 一条边都没有的 terrain 包没有意义")

    declared_axes = list(source.get("axes") or [])
    cache: dict[str, dict[str, dict]] = {}
    edges: list[dict] = []
    covered: list[str] = []

    for index, raw in enumerate(raw_edges):
        where = f"edges[{index}]"
        for key in ("from_id", "to_id", "strength"):
            value = raw.get(key)
            if not isinstance(value, str) or not value:
                raise AssembleError(f"{where} 缺 `{key}`")

        strength = raw["strength"]
        if strength not in STRENGTHS:
            raise AssembleError(
                f"{where} 的 strength 是 `{strength}`，只认 {' / '.join(STRENGTHS)}"
            )

        for key in ("from_id", "to_id"):
            endpoint = raw[key]
            if ":" not in endpoint:
                raise AssembleError(f"{where} 的 {key} 不是 `<plugin>:<local>` 形态：{endpoint}")
            pack_id = endpoint.split(":", 1)[0]
            if pack_id == source["id"]:
                raise AssembleError(
                    f"{where} 的 {key} 指向 terrain 自己 —— 地形边跨包，不该自指"
                )
            axis = node_axis(pack_id, endpoint, cache)
            if axis not in covered:
                covered.append(axis)

        edges.append(
            {
                "type": "prerequisite",
                "from_id": raw["from_id"],
                "to_id": raw["to_id"],
                "strength": strength,
            }
        )

    unknown = [axis for axis in covered if axis not in declared_axes]
    if unknown:
        raise AssembleError(
            f"边实际跨到的轴 {unknown} 不在源 axes[]（{declared_axes}）里"
            " —— 加边就要同时改声明，否则清单说本包不涉及那条轴"
        )

    counts = {"required": 0, "recommended": 0}
    for edge in edges:
        counts[edge["strength"]] += 1

    pack = {
        "plugin_id": source["id"],
        "name": source["name"],
        "version": source["version"],
        "kinds": ["terrain"],
        "namespace": source["id"],
        "schema_version": 1,
        "skeleton_requires": source["skeleton_requires"],
        "deps": list(source.get("deps") or []),
        # 与载荷包同口径：许可是源的属性（写在 sources[].segments[].license），
        # 包本身还没定，所以不编一个 SPDX 出来。
        "license": "unspecified",
        "author": "weltuhr",
        "origin": f"content/{source['id']}",
        "review_state": "pending",
        "signature": None,
        "axes": declared_axes,
        "terrain": {
            "edge_counts": counts,
            # 排一次序：源里加边的顺序变了，产物不该跟着变。
            "axes_covered": sorted(covered),
        },
        # 六段齐全（`pack_reader` 缺一段即格式错误）。五段为空不是省略：
        # terrain 包本来就没有节点、条目、源、体系、方法。
        "nodes": [],
        "edges": edges,
        "entries": [],
        "sources": [],
        "schemes": [],
        "methods": [],
    }
    return pack, counts


def write_pack(out: str | None = None) -> tuple[str, dict[str, int]]:
    pack, counts = assemble()

    text = json.dumps(pack, **_JSON_KWARGS) + "\n"
    out = out or os.path.join(TERRAIN_DIR, PACK_NAME)
    # 先写临时文件再改名：中途失败不留半截 pack.json（与其余装配器同法）。
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(out), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.replace(tmp, out)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return out, counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="跨轴先修边源装配成单文件 pack.json")
    parser.add_argument("--check", action="store_true", help="只跑校验，不落盘")
    parser.add_argument("--out", help="产出路径，默认 content/terrain/pack.json")
    args = parser.parse_args(argv)

    try:
        if args.check:
            pack, counts = assemble()
            axes = " · ".join(pack["terrain"]["axes_covered"])
            print(
                f"[ok] 校验通过：边 {len(pack['edges'])}"
                f"（required {counts['required']} / recommended {counts['recommended']}）· 跨轴 {axes}"
            )
            return 0

        out, counts = write_pack(args.out)
        print(f"[ok] 写入 {os.path.relpath(out)}")
        print(
            f"     边 {counts['required'] + counts['recommended']}"
            f"（required {counts['required']} / recommended {counts['recommended']}）"
        )
        print(f"     字节 {os.path.getsize(out)}")
        return 0
    except AssembleError as exc:
        print(f"[fail] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
