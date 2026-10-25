"""旧五段源 → 单文件 `pack.json`（`SPEC-PACK-005` 的目标形态）。

用法：
    python content/tools/assemble_pack.py            装配 `content/` 下全部空间
    python content/tools/assemble_pack.py python     只装配一个空间

与 `build.py` 的分工（**过渡态，两个脚本并存是有意的，但只能有一个在跑产品链路**）：

| 脚本 | 产出 | 消费方 |
|---|---|---|
| `build.py` | `<空间>/dist/pack.json` = 清单 + 五段 + `meta` 信封（**作废形态**） | `verify.py --suite` 的 37 个 fixture |
| 本脚本 | `<空间>/pack.json` = 清单 + 六段（目标形态） | 客户端 `PackProbe` → `readPack` |

`build.py` 那侧一整套要随三包重建一并删除（见 `SPEC-PACK-005` 的「迁移状态」段）。
在那之前先把产品链路接通：客户端探的是 `<包根>/pack.json`，`dist/` 下那个它不认。

派生口径 —— **旧数据没有的字段一律机械派生，不撰写内容**：

| 新字段 | 来源 | 说明 |
|---|---|---|
| `nodes[].id` | `items[].id` | `python/dm-copy` → `python:dm-copy`（新 id 是 `{plugin_id}:{local_id}`） |
| `nodes[].level_slot` | `domainId` | 每个 `domainId` 一个 `system` 节点，其下 150 条为 `planet` |
| `nodes[].axis` | 常量 `AXIS` | 旧 `sixAxis` 已废（`ADR-0005`），三轴里只 `occupation` 表达「岗位技能」 |
| `edges[]` | `edges[].type` | `strong`→`required`；`weak`/`unknown`→`recommended`（旧 `unknown` 表达不了强度，取最近的一档并在下方登记） |
| `entries[].criteria[].statement` | `questions[].answer` | `"能说出：" + answer`。**模板 + 原文**，不是新写的句子 |
| `entries[].quiz[]` | `questions[]` | 原题无选项、无判定形式 ⇒ `type=freeform`、`judge=self` |
| `sources[].appliesTo.node_scope` | `items[].sourceRefs` | 反查：引用了这份源的节点 id |
| `payload.counts` | 实扫 | 不手填 —— `readPack` 会拿它和 `nodes[]` 对账 |

**不派生的两项**：`entries[].steps` 与 `entries[].body`。旧数据里根本没有，编不出来；
106 条没有题目的节点连 `entry` 都不建（界面如实显示「暂无」）。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import validator  # noqa: E402

CONTENT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK_NAME = "pack.json"

# 三轴里只 `occupation` 表达「岗位技能」：`discipline` / `major` 是骨架目录的轴，
# 载荷挂进去要先有骨架节点（`B13b` 的 `skeleton-*` 目录），而本空间目前是编外的。
AXIS = "occupation"

# 编外根：不是任何骨架恒星下的节点（`entity-fields` §1 `attach_to`）。
ATTACH_TO = "@extra/root"

# 旧出处等级 → 新 `AuthorityLevel`（`entity-fields` §11 已废除 `L` 编号）。
AUTHORITY = {"L0": "official", "L1": "standard", "L2": "textbook", "L4": "community"}

# 旧边类型 → 先修强度。`unknown`（指向未知）在旧模型里不表达强度，
# 归到 `recommended`：它不参与 `⪯` 闭包，与「指向未知」一样不构成硬约束。
EDGE_STRENGTH = {"strong": "required", "weak": "recommended", "unknown": "recommended"}

# 与 `build.py` 同一组序列化参数：换任何一项，同一 commit 两次装配就 byte 不等。
_JSON_KWARGS = {"ensure_ascii": False, "sort_keys": True, "indent": 2, "separators": (",", ": ")}


class AssembleError(Exception):
    pass


def _local(item_id: str) -> str:
    """`python/dm-copy` → `dm-copy`；已是裸串时原样返回。"""
    return item_id.split("/", 1)[1] if "/" in item_id else item_id


def _node_id(item_id: str, plugin_id: str) -> str:
    return f"{plugin_id}:{_local(item_id)}"


def _domain_slug(domain_id: str) -> str:
    """`python/data-model` → `dom-data-model`。

    加 `dom-` 前缀是必须的：不加的话 `python/control` 这个域与可能存在的
    `python/control` 条目会撞同一个 id，而撞了之后 `readPack` 会以
    「段内 id 重复」整包拒绝 —— 那是一条能看懂的错，但没必要制造。
    """
    return f"dom-{_local(domain_id)}"


def build_nodes(manifest: dict, items: list) -> tuple[list[dict], dict[str, str]]:
    """返回 (nodes, {旧 item id: 新 node id})。"""
    plugin_id = manifest["id"]
    nodes: list[dict] = []
    node_of: dict[str, str] = {}

    domains: list[str] = manifest.get("domainIds") or []
    for domain in domains:
        nodes.append(
            {
                "id": f"{plugin_id}:{_domain_slug(domain)}",
                "axis": AXIS,
                "level_slot": "system",
                "official_code": None,
                "name": _local(domain).replace("-", " "),
                "slug": _domain_slug(domain),
                "scope": "S1",
                "pack_id": plugin_id,
                "status": "live",
                "tags": [],
                "catalog_refs": [],
            }
        )

    for item in items:
        node_id = _node_id(item["id"], plugin_id)
        node_of[item["id"]] = node_id
        nodes.append(
            {
                "id": node_id,
                "axis": AXIS,
                "level_slot": "planet",
                "official_code": None,
                "name": item["title"],
                "slug": _local(item["id"]),
                "scope": "S1",
                "pack_id": plugin_id,
                "status": "live",
                "tags": [],
                "catalog_refs": [],
                "type": item["type"],
                "layer": item["layer"],
                "requirements": item["requirements"],
            }
        )
    return nodes, node_of


def build_edges(manifest: dict, items: list, edges: list, node_of: dict[str, str]) -> tuple[list[dict], int]:
    """返回 (edges, 未能映射的条数)。

    父边两条来源：`attach_to`（每个 `system` 一条，物化 `main`）+ 每条 item 到它
    所属 `domainId` 的那条。先修边直接搬。
    """
    plugin_id = manifest["id"]
    out: list[dict] = []
    for domain in manifest.get("domainIds") or []:
        out.append(
            {
                "type": "parent",
                "child_id": f"{plugin_id}:{_domain_slug(domain)}",
                "parent_id": ATTACH_TO,
                "kind": "main",
            }
        )
    for item in items:
        out.append(
            {
                "type": "parent",
                "child_id": node_of[item["id"]],
                "parent_id": f"{plugin_id}:{_domain_slug(item['domainId'])}",
                "kind": "main",
            }
        )

    dropped = 0
    for edge in edges:
        src, dst = edge.get("from"), edge.get("to")
        if src not in node_of or dst not in node_of:
            # 端点对不上就是旧数据自己的事（`E-EDGE-REF` 也只在 `unknown` 时放行）。
            # 这里不猜、不补，计入 dropped 由调用方报出来。
            dropped += 1
            continue
        out.append(
            {
                "type": "prerequisite",
                "from_id": node_of[src],
                "to_id": node_of[dst],
                "strength": EDGE_STRENGTH.get(edge.get("type"), "recommended"),
            }
        )
    return out, dropped


def build_entries(items: list, questions: list, node_of: dict[str, str]) -> list[dict]:
    """有题目的节点才建 entry。

    `criteria` 与 `quiz` 必须 1:1（`entity-fields` §9.3）：旧题目没有能力断言这一栏，
    于是断言由答案原文 + 固定前缀派生。**这是模板，不是撰写** —— 想要真正的断言，
    得重写题目，那是内容工作。

    一个条目可以有多道题（`python/fn-default-arg` 就有两条），所以按 `itemId`
    **分组**而不是建 1:1 字典 —— 后者会静默吞掉同一条目上的第二道题。
    """
    by_item: dict[str, list[dict]] = {}
    for question in questions:
        if question.get("itemId") in node_of:
            by_item.setdefault(question["itemId"], []).append(question)

    out: list[dict] = []
    for item in items:
        group = by_item.get(item["id"])
        if not group:
            continue
        criteria: list[dict] = []
        quiz: list[dict] = []
        for index, question in enumerate(group, start=1):
            criterion_id = f"c{index}"
            criteria.append({"id": criterion_id, "statement": f"能说出：{question['answer']}"})
            quiz.append(
                {
                    "id": question["id"],
                    "criterion_id": criterion_id,
                    "type": "freeform",
                    "prompt": question["prompt"],
                    "answer": question["answer"],
                    "judge": "self",
                }
            )
        out.append(
            {
                "node_id": node_of[item["id"]],
                "summary": None,
                "outcomes": [],
                "resources": [],
                "aliases": [],
                "keywords": [],
                "body": None,
                "steps": [],
                "selfCheck": [],
                "criteria": criteria,
                "quiz": quiz,
                "source_refs": list(item.get("sourceRefs") or []),
            }
        )
    return out


def build_sources(excerpts: list, items: list, node_of: dict[str, str]) -> list[dict]:
    """`node_scope` 由 `items[].sourceRefs` 反查 —— 旧摘录的 `appliesTo` 用的是
    已废的 `spaceId` / `sixAxis`，一个都映射不过来，反查比硬塞一个恒真的过滤好。"""
    users: dict[str, list[str]] = {}
    for item in items:
        for ref in item.get("sourceRefs") or []:
            users.setdefault(ref, []).append(node_of[item["id"]])

    out: list[dict] = []
    for source in excerpts:
        out.append(
            {
                "id": source["id"],
                "name": source["name"],
                "kind": "material",
                "authority_level": AUTHORITY.get(source.get("authorityLevel"), "reference"),
                "version": source["version"],
                "segments": [
                    {
                        "text": seg["text"],
                        "locator": seg["locator"],
                        "license": seg["license"],
                    }
                    for seg in source.get("segments") or []
                ],
                "appliesTo": {
                    "axes": [AXIS],
                    "node_scope": sorted(users.get(source["id"], [])),
                },
            }
        )
    return out


def build_schemes(schemes: list, node_of: dict[str, str]) -> list[dict]:
    out: list[dict] = []
    for scheme in schemes:
        nodes = [node_of[n] for n in scheme.get("nodes") or [] if n in node_of]
        if not nodes:
            continue
        out.append(
            {
                "id": scheme["id"],
                "name": scheme["name"],
                "nodes": nodes,
                "authority_level": AUTHORITY.get(scheme.get("authorityLevel"), "reference"),
            }
        )
    return out


def assemble(root: str) -> tuple[dict, list[str]]:
    """返回 (pack 对象, 装配期提示)。提示为空不代表没问题 —— 源数据本身先过 validator。"""
    manifest, segments, issues = validator.load_source(root)
    if manifest is None:
        raise AssembleError("；".join(str(i) for i in issues))
    issues.extend(validator.validate(manifest, segments))
    if issues:
        raise AssembleError("；".join(str(i) for i in issues))

    items = segments.get("items") or []
    edges = segments.get("edges") or []
    questions = segments.get("questions") or []
    excerpts = segments.get("excerpts") or []
    schemes = segments.get("schemes") or []

    plugin_id = manifest["id"]
    nodes, node_of = build_nodes(manifest, items)
    new_edges, dropped = build_edges(manifest, items, edges, node_of)
    entries = build_entries(items, questions, node_of)
    sources = build_sources(excerpts, items, node_of)
    mapped_schemes = build_schemes(schemes, node_of)

    counts = {"star": 0, "system": 0, "planet": 0}
    for node in nodes:
        counts[node["level_slot"]] = counts.get(node["level_slot"], 0) + 1

    pack = {
        "plugin_id": plugin_id,
        "name": manifest["name"],
        "version": manifest["version"],
        "kinds": ["payload"],
        "namespace": plugin_id,
        "schema_version": 1,
        "skeleton_requires": ">=0.0.0",
        "deps": [],
        # 这两项旧清单里没有。**不编造**：`review_state` 是 `pending`（没人审过），
        # `license` 是 `unspecified`（源的许可写在 `sources[].segments[].license` 里，
        # 包本身还没定）。
        "license": "unspecified",
        "author": "weltuhr",
        "origin": f"content/{plugin_id}",
        "review_state": "pending",
        "signature": None,
        "axes": [AXIS],
        "payload": {
            "attach_to": ATTACH_TO,
            "subtree_root": "system",
            "level_range": ["system", "planet"],
            "counts": counts,
            "official_code_coverage": False,
            "path_reservations": [
                {"parent_id": ATTACH_TO, "slug": _domain_slug(domain)}
                for domain in manifest.get("domainIds") or []
            ],
            "sources": [s["id"] for s in sources],
            "schemes": [s["id"] for s in mapped_schemes],
            "has_steps": any(e["steps"] for e in entries),
            "has_criteria": any(e["criteria"] for e in entries),
            "has_quiz": any(e["quiz"] for e in entries),
            "quiz_types": sorted({q["type"] for e in entries for q in e["quiz"]}),
            "est_minutes_coverage": 0.0,
        },
        "nodes": nodes,
        "edges": new_edges,
        "entries": entries,
        "sources": sources,
        "schemes": mapped_schemes,
        "methods": [],
    }

    notes: list[str] = []
    if dropped:
        notes.append(f"{dropped} 条边的端点不在 nodes 里，未搬（旧数据自身问题）")
    notes.append(f"{len(items) - len(entries)} 条节点无题目，未建 entry（不编造步骤与正文）")
    return pack, notes


def write_pack(root: str, out: str | None = None) -> tuple[str, list[str]]:
    pack, notes = assemble(root)
    text = json.dumps(pack, **_JSON_KWARGS) + "\n"
    out = out or os.path.join(root, PACK_NAME)
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
    return out, notes


def discover_spaces(content_dir: str) -> list[str]:
    found = []
    for name in sorted(os.listdir(content_dir)):
        path = os.path.join(content_dir, name)
        if os.path.isdir(path) and os.path.isfile(os.path.join(path, "manifest.json")):
            found.append(path)
    return found


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="把旧五段源装配成单文件 pack.json")
    parser.add_argument("space", nargs="?", help="空间 id（content/ 下的目录名）")
    parser.add_argument("--out", help="产出路径，默认 <源目录>/pack.json")
    args = parser.parse_args(argv)

    if args.space:
        roots = [os.path.join(CONTENT_DIR, args.space)]
        if not os.path.isdir(roots[0]):
            print(f"找不到空间目录：{roots[0]}", file=sys.stderr)
            return 2
    else:
        roots = discover_spaces(CONTENT_DIR)
        if not roots:
            print(f"{CONTENT_DIR} 下没有任何空间", file=sys.stderr)
            return 2

    status = 0
    for root in roots:
        label = os.path.basename(os.path.normpath(root))
        try:
            out, notes = write_pack(root, args.out)
        except AssembleError as exc:
            status = 1
            print(f"[fail] {label}: {exc}", file=sys.stderr)
            continue
        print(f"[ok] {label} -> {os.path.relpath(out)}")
        for note in notes:
            print(f"    {note}")
    return status


if __name__ == "__main__":
    sys.exit(main())
