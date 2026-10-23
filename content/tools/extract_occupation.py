#!/usr/bin/env python3
"""把职业分类大典的原始抓取结果转成骨架源数据（`skeleton-catalog.md` 步骤 2）。

输入：`content/skeleton/source/occupation-2022-osta.json`（`fetch_occupation.py` 产出，
      原始响应逐字保留，不预处理）。
输出：`content/skeleton/occupation.json`。

用法（在 `content/` 下执行）：

    python tools/extract_occupation.py
    python tools/extract_occupation.py --check

判据来源
--------
`docs/specs/skeleton-catalog.md`
  · §二 三轴数据源 —— 只用职业分类大典，不拼接其他分类标准
  · §三 槽位映射 —— 角色轴占满五槽：supercluster / group / galaxy / cluster / star
  · §四 编号与定位 —— `id` = `<axis>/<official_code>`，`official_code` 原样（码内含连字符）
  · §五 节点数 —— 角色 2,225（1 + 8 + 79 + 450 + 1,687）
  · §六 步骤 2 —— 条目数逐轴相等，差异逐条说明
`docs/specs/path-rules.md`
  · P-01 `path` 是派生值，**本脚本不产出 `path` 字段**（只在校验里算出来查唯一性）
  · P-04 `slug` 字符集 `^[a-z0-9-]+$`（官方码本身就落在字符集内）
  · P-05 骨架段的 slug 由 `official_code` 派生（改名不改码）

名称清理
--------
大典原文在职业名称尾部标「数字职业」= `S`、「绿色职业」= `L`（两种都是时写作 `L/S`）。
这些标记是**分类标注，不是名称的一部分**，故剥离并转成标签 `digital` / `green`；
剥离结果逐条记入 `differences`，便于人工复核没有误伤真实名称。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKELETON_DIR = HERE.parent / "skeleton"
SOURCE_DIR = SKELETON_DIR / "source"
RAW_PATH = SOURCE_DIR / "occupation-2022-osta.json"

SLUG_RE = re.compile(r"^[a-z0-9-]+$")
MARK_RE = re.compile(r"\s*(L/S|S|L)\s*$")

AXIS = "occupation"
ROOT_NAME = "职业"

CATALOG = {
    "title": "中华人民共和国职业分类大典",
    "edition": "2022",
    "issuer": "人力资源社会保障部",
    "system": "技能人才评价工作网 · 职业分类系统",
    "url": "http://osta.mohrss.gov.cn/career",
    "file": "source/occupation-2022-osta.json",
    "note": "2022 年版，取自官方在线系统（含发布后增补，见 differences）",
}

# §三 槽位映射：角色轴的五层
SLOT_OF_DEPTH = {1: "group", 2: "galaxy", 3: "cluster", 4: "star"}

EXPECTED = {
    "supercluster": 1,
    "group": 8,
    "galaxy": 79,
    "cluster": 450,
    "star": 1687,
    "total": 2225,
}

TAG_NAME = [
    ("digital", "数字职业：大典原文名称尾标 S"),
    ("green", "绿色职业：大典原文名称尾标 L"),
]


def slug_of(code: str) -> str:
    """P-05：骨架段 slug 由官方码派生。官方码形如 `4-10-01-01`，已在字符集内。"""
    slug = code.lower()
    if not SLUG_RE.match(slug):
        raise ValueError("slug 无法由官方码派生：%r" % code)
    return slug


def clean_name(raw: str) -> tuple[str, list[str]]:
    """剥离名称尾部的 S / L / L/S 标注，返回 (名称, 标签)。"""
    s = raw.strip()
    tags: list[str] = []
    while True:
        m = MARK_RE.search(s)
        if not m:
            break
        marker = m.group(1)
        if "S" in marker:
            tags.append("digital")
        if "L" in marker:
            tags.append("green")
        s = s[: m.start()].strip()
    return s, sorted(set(tags))


def make_node(slot: str, code: str | None, name: str, parent_id: str,
              tags: list[str]) -> dict:
    return {
        "id": "skeleton:%s/%s" % (AXIS, code) if code else "skeleton:%s" % AXIS,
        "axis": AXIS,
        "level_slot": slot,
        "official_code": code,
        "name": name,
        "slug": slug_of(code) if code else AXIS,
        "scope": "S0",
        "pack_id": "skeleton",
        "status": "live",
        "parent_id": parent_id,
        "tags": tags,
    }


def counts_of(nodes: list[dict]) -> dict:
    counts: dict[str, int] = {}
    for n in nodes:
        counts[n["level_slot"]] = counts.get(n["level_slot"], 0) + 1
    counts["total"] = len(nodes)
    return counts


def build() -> dict:
    if not RAW_PATH.exists():
        raise SystemExit("[FAIL] 原始抓取结果不存在：%s（先跑 fetch_occupation.py）" % RAW_PATH)
    raw = json.loads(RAW_PATH.read_text(encoding="utf-8"))
    tree = raw["tree"]
    sub = raw["subordinate"]

    nodes = [make_node("supercluster", None, ROOT_NAME, "", [])]
    differences: list[dict] = []
    anomalies: list[str] = []
    empty_clusters: list[str] = []
    renamed: list[dict] = []

    for big in tree:
        big_code = big["careerCode"]
        name, tags = clean_name(big["careerName"])
        if name != big["careerName"].strip():
            renamed.append({"code": big_code, "raw": big["careerName"], "name": name})
        nodes.append(make_node("group", big_code, name, "skeleton:%s" % AXIS, tags))

        for mid in big.get("children") or []:
            mid_code = mid["careerCode"]
            name, tags = clean_name(mid["careerName"])
            if name != mid["careerName"].strip():
                renamed.append({"code": mid_code, "raw": mid["careerName"], "name": name})
            nodes.append(make_node("galaxy", mid_code, name,
                                   "skeleton:%s/%s" % (AXIS, big_code), tags))

            for small in mid.get("children") or []:
                small_code = small["careerCode"]
                name, tags = clean_name(small["careerName"])
                if name != small["careerName"].strip():
                    renamed.append({"code": small_code, "raw": small["careerName"],
                                    "name": name})
                nodes.append(make_node("cluster", small_code, name,
                                       "skeleton:%s/%s" % (AXIS, mid_code), tags))

                kids = sub.get(small_code) or []
                if not kids:
                    empty_clusters.append(small_code)
                for star in kids:
                    star_code = star["careerCode"]
                    if star_code.rsplit("-", 1)[0] != small_code:
                        anomalies.append("细类 %s 的前缀与小类 %s 不符" % (star_code, small_code))
                    sname, stags = clean_name(star["name"])
                    if sname != star["name"].strip():
                        renamed.append({"code": star_code, "raw": star["name"],
                                        "name": sname})
                    nodes.append(make_node("star", star_code, sname,
                                           "skeleton:%s/%s" % (AXIS, small_code), stags))

    counts = counts_of(nodes)
    # 与 2022 年版官方发布口径的差额，逐层说明（§六 步骤 2）
    differences = [
        {
            "layer": "cluster",
            "official_2022": 449,
            "actual": counts.get("cluster", 0),
            "delta": counts.get("cluster", 0) - 449,
            "reason": "官方系统为 2022 年版**发布后持续增补**的在线版本，小类净增 1 条；"
                      "系统接口不带发布批次字段（`versionId` 全为 2，`releaseTime` 全空），"
                      "故无法逐条指出是哪一条。按 §二 纪律 2「目录版本即骨架版本」，"
                      "骨架取系统当前状态，不剔除。",
        },
        {
            "layer": "star",
            "official_2022": 1636,
            "actual": counts.get("star", 0),
            "delta": counts.get("star", 0) - 1636,
            "reason": "同上。按 `id`（插入顺序）倒序，最上方一批为 2024–2025 年新职业"
                      "（生成式人工智能系统应用员、网络主播、储能电站运维管理员、"
                      "氢燃料电池制造工、具身智能机器人应用技术员等）；"
                      "`id >= 4693` 恰好 51 条，与差额相等，但**分界无法独立证明**"
                      "（相邻 id 无断层，工种数交叉验算未对上），故不据此打标签。",
        },
    ]
    if renamed:
        differences.append({
            "layer": "name",
            "count": len(renamed),
            "reason": "名称尾部 S / L / L/S 标注已剥离并转为 `digital` / `green` 标签"
                      "（大典原文用它们标数字职业与绿色职业，不属名称本体）。",
            "items": renamed,
        })

    data = {
        "schema": "weltuhr.skeleton.source/1",
        "axis": AXIS,
        "catalog": dict(CATALOG),
        "source": {
            "path": CATALOG["file"],
            "bytes": RAW_PATH.stat().st_size,
            "sha256": hashlib.sha256(RAW_PATH.read_bytes()).hexdigest(),
            "retrieved": raw["meta"]["retrieved"],
            "requests": raw["meta"]["requests"],
        },
        "tag_vocabulary": {k: v for k, v in TAG_NAME},
        "counts": counts,
        "expected": dict(EXPECTED),
        "differences": differences,
        "anomalies": anomalies,
        # 大典原文即为空的小类（「其他……人员」层，如 `2-01-99`）：结构事实，不是缺陷
        "empty_clusters": empty_clusters,
        "nodes": nodes,
    }
    return data


def check(data: dict) -> int:
    """§六 步骤 4 的五项机器校验 + id / slug / path 三条独立断言。"""
    nodes = data["nodes"]
    fails: list[str] = []

    ids = [n["id"] for n in nodes]
    if len(ids) != len(set(ids)):
        dup = sorted({i for i in ids if ids.count(i) > 1})
        fails.append("id 全局不唯一：%s" % dup[:5])

    codes = [n["official_code"] for n in nodes if n["official_code"]]
    if len(codes) != len(set(codes)):
        dup = sorted({c for c in codes if codes.count(c) > 1})
        fails.append("official_code 轴内不唯一：%s" % dup[:5])

    by_id = {n["id"]: n for n in nodes}
    roots = [n for n in nodes if not n["parent_id"]]
    if len(roots) != 1 or roots[0]["level_slot"] != "supercluster":
        fails.append("轴根不是恰好一个 supercluster：%s" % [r["id"] for r in roots])

    for n in nodes:
        if not SLUG_RE.match(n["slug"]):
            fails.append("slug 非法：%s/%s" % (n["id"], n["slug"]))
        if n["parent_id"] and n["parent_id"] not in by_id:
            fails.append("孤儿：%s -> %s" % (n["id"], n["parent_id"]))

    seen_slug: dict[tuple[str, str], str] = {}
    for n in nodes:
        key = (n["parent_id"], n["slug"])
        if key in seen_slug:
            fails.append("同父 slug 重复：%s 与 %s" % (seen_slug[key], n["id"]))
        seen_slug[key] = n["id"]

    paths: dict[str, str] = {}

    def path_of(node_id: str, guard: frozenset[str]) -> str:
        if node_id in paths:
            return paths[node_id]
        n = by_id[node_id]
        if not n["parent_id"]:
            paths[node_id] = n["slug"]
            return n["slug"]
        if node_id in guard:
            fails.append("有环：%s" % node_id)
            return n["slug"]
        paths[node_id] = path_of(n["parent_id"], guard | {node_id}) + "/" + n["slug"]
        return paths[node_id]

    for n in nodes:
        path_of(n["id"], frozenset())

    duplicated: dict[str, list[str]] = {}
    for n in nodes:
        duplicated.setdefault(paths[n["id"]], []).append(n["id"])
    clashes = {p: v for p, v in duplicated.items() if len(v) > 1}
    if clashes:
        fails.append("path 全局重复：%s" % list(clashes.items())[:3])

    for n in nodes:
        if n["level_slot"] != "star":
            continue
        cur = n
        depth = 0
        while cur["parent_id"]:
            cur = by_id[cur["parent_id"]]
            depth += 1
            if depth > 8:
                fails.append("父链过深：%s" % n["id"])
                break
        else:
            if cur["level_slot"] != "supercluster":
                fails.append("star 父链未到轴根：%s" % n["id"])

    counts = counts_of(nodes)
    expected = EXPECTED
    for slot, want in expected.items():
        got = counts.get(slot, 0)
        if got != want:
            fails.append("%s 条数 %d != 期望 %d" % (slot, got, want))
    for slot, got in counts.items():
        if slot not in expected:
            fails.append("出现未预期的槽位 %s（%d 条）" % (slot, got))

    if data["anomalies"]:
        fails.append("解析异常 %d 条（见 anomalies 字段）" % len(data["anomalies"]))

    print("[%s] axis=%s 节点=%d 槽位=%s" % ("OK" if not fails else "FAIL", AXIS,
                                            len(nodes),
                                            json.dumps(counts, ensure_ascii=False,
                                                       sort_keys=True)))
    print("       path 样例：%s" % ", ".join(sorted(paths.values())[::400][:3]))
    print("       无细类的小类 %d 个（大典原文即为空，非缺陷）"
          % len(data.get("empty_clusters") or []))
    for f in fails:
        print("       - " + f)
    return 0 if not fails else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="角色轴骨架源数据抽取")
    parser.add_argument("--check", action="store_true", help="跑 §六 步骤 4 的机器校验")
    args = parser.parse_args()

    data = build()
    out = SKELETON_DIR / "occupation.json"
    text = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    out.write_text(text, encoding="utf-8", newline="\n")
    print("[OK] 写入 %s（%d 字节）" % (out.relative_to(SKELETON_DIR.parent),
                                     len(text.encode("utf-8"))))
    if args.check:
        return check(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
