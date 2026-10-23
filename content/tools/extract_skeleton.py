#!/usr/bin/env python3
"""从教育部官方目录 PDF 抽取骨架源数据（`skeleton-catalog.md` 步骤 2）。

输入：`content/skeleton/source/` 下的两份官方 PDF（raw，原样入库，不预处理）。
输出：`content/skeleton/discipline.json` · `content/skeleton/major.json`。

用法（在 `content/` 下执行）：

    python tools/extract_skeleton.py --axis discipline
    python tools/extract_skeleton.py --axis major
    python tools/extract_skeleton.py --axis discipline --check

依赖：`pdfplumber`（仅本脚本用，内容管线其余脚本不依赖它）。

判据来源
--------
`docs/specs/skeleton-catalog.md`
  · §二 三轴数据源 —— 只用这两份目录，不拼接 GB/T 13745
  · §三 槽位映射 —— 学科轴只占 supercluster / group / star
  · §四 编号与定位 —— `id` = `<axis>/<official_code>`，`official_code` 原样（含前导零）
  · §五 节点数 —— 学科 199 · 专业 951
  · §六 步骤 2 —— 条目数逐轴相等，差异逐条说明
`docs/specs/path-rules.md`
  · P-01 `path` 是派生值，**本脚本不产出 `path` 字段**
  · P-04 `slug` 字符集 `^[a-z0-9-]+$`
  · P-05 骨架段的 slug 由 `official_code` 派生（改名不改码）

`id` 前缀的口径见 `entity-fields.md` §2（骨架节点 `skeleton:{local_id}`）与
`constants.dart` 的 `skeletonNodePrefix`；`local_id` 取 `skeleton-catalog.md` §四 的
`<axis>/<official_code>` —— 两处合起来才既不与实体表冲突、又不让两轴的 `0101` 撞车。
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:  # pragma: no cover
    sys.exit("[FAIL] 缺 pdfplumber：pip install pdfplumber")

HERE = Path(__file__).resolve().parent
SKELETON_DIR = HERE.parent / "skeleton"
SOURCE_DIR = SKELETON_DIR / "source"

SLUG_RE = re.compile(r"^[a-z0-9-]+$")
FOOTER_RE = re.compile(r"^[\u2014\u2013-]\s*\d+\s*[\u2014\u2013-]$")

# 轴根（`path-rules.md` P-02 的首段；取值同 `entity-fields.md` §2 的 axis 枚举）
AXIS_ROOT = {
    "discipline": {"slug": "discipline", "name": "学科"},
    "major": {"slug": "major", "name": "专业"},
}

CATALOG = {
    "discipline": {
        "title": "研究生教育学科专业目录",
        "edition": "2022",
        "document_no": "学位〔2022〕15号",
        "published": "2022-09-13",
        "issuer": "国务院学位委员会 · 教育部",
        "url": "https://www.moe.gov.cn/srcsite/a22/moe_833/202209/w020220914572994461110.pdf",
        "file": "source/disc-2022-moe.pdf",
    },
    "major": {
        "title": "普通高等学校本科专业目录",
        "edition": "2025",
        "document_no": "教高函〔2025〕3号",
        "published": "2025-04-01",
        "issuer": "教育部",
        "url": "http://www.moe.gov.cn/srcsite/A08/moe_1034/s4930/202504/W020250422312780837078.pdf",
        "file": "source/major-2025-moe.pdf",
    },
}

EXPECTED = {
    "discipline": {"supercluster": 1, "group": 14, "star": 184, "total": 199},
    "major": {"supercluster": 1, "group": 12, "galaxy": 93, "star": 845, "total": 951},
}

# 学科轴有三条专业学位类别在 PDF 里不单列，只出现在对应一级学科的条目注释中
# （「同时设专业学位类别，代码为 105X」）。§五 的 67 含这三条，故按注释补入。
DISPLACED_DEGREE = [
    {"code": "1051", "from": "1002", "note": "PDF 未单列；据 1002 临床医学条目注释「同时设专业学位类别，代码为 1051」补入"},
    {"code": "1052", "from": "1003", "note": "PDF 未单列；据 1003 口腔医学条目注释「同时设专业学位类别，代码为 1052」补入"},
    {"code": "1055", "from": "1007", "note": "PDF 未单列；据 1007 药学条目注释「同时设专业学位类别，代码为 1055」补入"},
]

TAG_NAME = [
    ("degree-category", "专业学位类别：官方码第三位「从 5 开始」"),
    ("master-only", "名称后加 * 的专业学位类别：仅可授硕士专业学位"),
    ("state-controlled", "专业代码后加 K：国家控制布点专业"),
    ("special", "专业代码后加 T：特设专业"),
]


def read_lines(pdf_path: Path) -> list[str]:
    """逐页取文本行，丢掉页码脚注与空行。"""
    lines: list[str] = []
    with pdfplumber.open(str(pdf_path)) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            for raw in text.splitlines():
                s = raw.strip()
                if not s or FOOTER_RE.match(s):
                    continue
                lines.append(s)
    return lines


def split_name(raw: str) -> tuple[str, str | None, list[str]]:
    """把「名称（注释）*」拆成 (名称, 注释, 标签)。"""
    s = raw.strip()
    tags: list[str] = []
    m = re.search(r"\s*\*+\s*$", s)
    if m:
        tags.append("master-only")
        s = s[: m.start()]
    note = None
    m = re.search(r"[（(]([^（）()]*)[）)]\s*$", s)
    if m:
        note = m.group(1).strip()
        if note.startswith("注："):
            note = note[2:].strip()
        s = s[: m.start()]
    return s.strip(), note, tags


def slug_of(code: str) -> str:
    """P-05：骨架段 slug 由官方码派生，小写化并去掉字符集外的字符。"""
    slug = re.sub(r"[^a-z0-9-]", "", code.lower())
    if not slug or not SLUG_RE.match(slug):
        raise ValueError("slug 无法由官方码派生：%r" % code)
    return slug


def code_tags(code: str) -> list[str]:
    tags = []
    suffix = code[len(code.rstrip("KT")):]
    if "K" in suffix:
        tags.append("state-controlled")
    if "T" in suffix:
        tags.append("special")
    return sorted(tags)


def make_node(axis: str, slot: str, code: str | None, name: str,
              parent_id: str, note: str | None, tags: list[str]) -> dict:
    node = {
        "id": "skeleton:%s/%s" % (axis, code) if code else "skeleton:%s" % axis,
        "axis": axis,
        "level_slot": slot,
        "official_code": code,
        "name": name,
        "slug": slug_of(code) if code else AXIS_ROOT[axis]["slug"],
        "scope": "S0",
        "pack_id": "skeleton",
        "status": "live",
        "parent_id": parent_id,
        "tags": tags,
    }
    if note:
        # 源层专用字段：目录原文的括号注释（如「可授教育学、理学学位」）。
        # 构建 skeleton 包时不入包体，见 skeleton/README.md。
        node["catalog_note"] = note
    return node


def parse_discipline(lines: list[str]) -> tuple[list[dict], list[dict], list[str]]:
    root_id = "skeleton:discipline"
    nodes = [make_node("discipline", "supercluster", None, AXIS_ROOT["discipline"]["name"],
                       "", None, [])]
    anomalies: list[str] = []
    men_code = ""
    pending: dict | None = None
    started = False

    for s in lines:
        if not started:
            if re.match(r"^01\s+\S", s) and not re.match(r"^\d{4}", s):
                started = True
            else:
                continue

        m2 = re.match(r"^(\d{2})\s+(\D.*)$", s)
        if m2:
            men_code = m2.group(1)
            name, note, tags = split_name(m2.group(2))
            nodes.append(make_node("discipline", "group", men_code, name,
                                   root_id, note, tags))
            pending = None
            continue

        m4 = re.match(r"^(\d{4})\s+(.*)$", s)
        if m4:
            code, rest = m4.group(1), m4.group(2)
            if code[:2] != men_code:
                anomalies.append("一级/学位类别 %s 的前缀与当前门类 %s 不符" % (code, men_code))
            name, note, tags = split_name(rest)
            if code[2] in "56789":  # 说明第三条：代码第三位「从 5 开始」的为专业学位类别
                tags = sorted(set(tags) | {"degree-category"})
            node = make_node("discipline", "star", code, name,
                             "skeleton:discipline/%s" % men_code, note, tags)
            nodes.append(node)
            pending = node if rest.count("（") > rest.count("）") else None
            continue

        # 名称跨页/跨行续行
        if pending is not None:
            pending["name"] += s
            name, note, tags = split_name(pending["name"])
            pending["name"] = name
            if note:
                pending["catalog_note"] = note
            if tags:
                pending["tags"] = sorted(set(pending["tags"]) | set(tags))
            pending = None
        else:
            anomalies.append("无法归属的行：%s" % s[:40])

    return nodes, [], anomalies


def parse_major(lines: list[str]) -> tuple[list[dict], list[dict], list[str]]:
    root_id = "skeleton:major"
    nodes = [make_node("major", "supercluster", None, AXIS_ROOT["major"]["name"],
                       "", None, [])]
    anomalies: list[str] = []
    men_code = ""
    cls_code = ""
    pending: dict | None = None
    started = False

    for s in lines:
        if not started:
            m = re.match(r"^(\d{2})\s+学科门类[：:]\s*(.+)$", s)
            if m:
                started = True
            else:
                continue

        m0 = re.match(r"^(\d{2})\s+学科门类[：:]\s*(.+)$", s)
        if m0:
            men_code = m0.group(1)
            cls_code = ""
            name, note, tags = split_name(m0.group(2))
            nodes.append(make_node("major", "group", men_code, name, root_id, note, tags))
            pending = None
            continue

        m6 = re.match(r"^(\d{6,7}[KT]*)\s+(.*)$", s)
        if m6:
            code, rest = m6.group(1), m6.group(2)
            if code[:4] != cls_code:
                anomalies.append("专业 %s 的前缀与当前专业类 %s 不符" % (code, cls_code))
            name, note, tags = split_name(rest)
            node = make_node("major", "star", code, name,
                             "skeleton:major/%s" % cls_code, note,
                             sorted(set(tags) | set(code_tags(code))))
            nodes.append(node)
            pending = node if rest.count("（") > rest.count("）") else None
            continue

        m4 = re.match(r"^(\d{4})\s+(.*)$", s)
        if m4:
            code, rest = m4.group(1), m4.group(2)
            if code[:2] != men_code:
                anomalies.append("专业类 %s 的前缀与当前门类 %s 不符" % (code, men_code))
            cls_code = code
            name, note, tags = split_name(rest)
            if not name.endswith("类"):
                anomalies.append("专业类 %s 的名称不以「类」结尾：%s" % (code, name))
            nodes.append(make_node("major", "galaxy", code, name,
                                   "skeleton:major/%s" % men_code, note, tags))
            pending = None
            continue

        if pending is not None:
            pending["name"] += s
            name, note, tags = split_name(pending["name"])
            pending["name"] = name
            if note:
                pending["catalog_note"] = note
            pending = None
        else:
            anomalies.append("无法归属的行：%s" % s[:40])

    return nodes, [], anomalies


def fill_displaced_degree(nodes: list[dict]) -> tuple[list[dict], list[dict]]:
    """补入 PDF 只写在注释里的三条专业学位类别（§五 的 67 条含它们）。"""
    by_id = {n["id"]: n for n in nodes}
    differences: list[dict] = []
    for item in DISPLACED_DEGREE:
        source = by_id.get("skeleton:discipline/%s" % item["from"])
        if source is None:
            raise SystemExit("[FAIL] 补录依据缺失：找不到 %s" % item["from"])
        new_id = "skeleton:discipline/%s" % item["code"]
        if new_id in by_id:
            continue
        node = make_node("discipline", "star", item["code"], source["name"],
                         source["parent_id"], None, ["degree-category"])
        nodes.append(node)
        differences.append({
            "axis": "discipline",
            "code": item["code"],
            "name": source["name"],
            "reason": item["note"],
        })
    # 门类内按官方码升序，与目录的印刷顺序一致
    order = {n["id"]: i for i, n in enumerate(nodes)}
    ordered = sorted(nodes, key=lambda n: (order.get(n["parent_id"], -1),
                                           n["official_code"] or ""))
    return ordered, differences


def counts_of(nodes: list[dict]) -> dict:
    counts: dict[str, int] = {}
    for n in nodes:
        counts[n["level_slot"]] = counts.get(n["level_slot"], 0) + 1
    counts["total"] = len(nodes)
    return counts


def build(axis: str, retrieved: str) -> dict:
    entry = CATALOG[axis]
    pdf_path = SKELETON_DIR / entry["file"]
    if not pdf_path.exists():
        raise SystemExit("[FAIL] 源文件不存在：%s" % pdf_path)
    lines = read_lines(pdf_path)
    if axis == "discipline":
        nodes, _, anomalies = parse_discipline(lines)
        nodes, differences = fill_displaced_degree(nodes)
    else:
        nodes, _, anomalies = parse_major(lines)
        differences = []

    data = {
        "schema": "weltuhr.skeleton.source/1",
        "axis": axis,
        "catalog": dict(entry),
        "source": {
            "path": entry["file"],
            "bytes": pdf_path.stat().st_size,
            "sha256": hashlib.sha256(pdf_path.read_bytes()).hexdigest(),
            "retrieved": retrieved,
        },
        "tag_vocabulary": {k: v for k, v in TAG_NAME},
        "counts": counts_of(nodes),
        "expected": EXPECTED[axis],
        "differences": differences,
        "anomalies": anomalies,
        "nodes": nodes,
    }
    return data


def check(data: dict) -> int:
    """§六 步骤 4 的五项机器校验 + 两条 path 唯一性（算得出，落不下来）。"""
    nodes = data["nodes"]
    axis = data["axis"]
    fails = []

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

    # 主父唯一：每个节点恰好一个父节点指向它（结构上由 single parent_id 保证，独立断言）
    seen_slug: dict[tuple[str, str], str] = {}
    for n in nodes:
        key = (n["parent_id"], n["slug"])
        if key in seen_slug:
            fails.append("同父 slug 重复：%s 与 %s" % (seen_slug[key], n["id"]))
        seen_slug[key] = n["id"]

    # 无环 + 每个 star 的父链到轴根 + path 唯一（path 只算不存，P-01）
    paths: dict[str, str] = {}

    def path_of(node_id: str, guard: set[str]) -> str:
        if node_id in paths:
            return paths[node_id]
        n = by_id[node_id]
        if not n["parent_id"]:
            paths[node_id] = n["slug"]
            return n["slug"]
        if n["parent_id"] in guard:
            fails.append("有环：%s" % node_id)
            return n["slug"]
        guard = guard | {node_id}
        paths[node_id] = path_of(n["parent_id"], guard) + "/" + n["slug"]
        return paths[node_id]

    for n in nodes:
        path_of(n["id"], set())

    duplicated = {}
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
    expected = EXPECTED[axis]
    for slot, want in expected.items():
        got = counts.get(slot, 0)
        if slot == "total":
            if got != want:
                fails.append("总条数 %d != 期望 %d" % (got, want))
        elif got != want:
            fails.append("%s 条数 %d != 期望 %d" % (slot, got, want))
    for slot, got in counts.items():
        if slot not in expected:
            fails.append("出现未预期的槽位 %s（%d 条）" % (slot, got))

    if data["anomalies"]:
        fails.append("解析异常 %d 条（见 anomalies 字段）" % len(data["anomalies"]))

    print("[%s] axis=%s 节点=%d 槽位=%s" % ("OK" if not fails else "FAIL", axis, len(nodes),
                                            json.dumps(counts, ensure_ascii=False, sort_keys=True)))
    print("       path 样例：%s" % ", ".join(sorted(paths.values())[:3]))
    for f in fails:
        print("       - " + f)
    return 0 if not fails else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="骨架源数据抽取")
    parser.add_argument("--axis", required=True, choices=["discipline", "major"])
    parser.add_argument("--check", action="store_true", help="跑 §六 步骤 4 的机器校验")
    parser.add_argument("--retrieved", default=datetime.date.today().isoformat())
    args = parser.parse_args()

    data = build(args.axis, args.retrieved)
    out = SKELETON_DIR / ("%s.json" % args.axis)
    text = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    out.write_text(text, encoding="utf-8", newline="\n")
    print("[OK] 写入 %s（%d 字节）" % (out.relative_to(SKELETON_DIR.parent), len(text.encode("utf-8"))))
    if args.check:
        return check(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
