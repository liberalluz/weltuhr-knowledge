"""pack 源数据校验器 —— 纯标准库，零第三方依赖。

判据来源（本文件不重述裁定，只给出指回条目的 issue code）：

- `docs/specs/PACK-content-pack.md` §二 pack 格式（`SPEC-PACK-005` … `009`）
- `docs/specs/FND-foundation.md`（`SPEC-FND-004` 六要件三态 · `005` DAG · `013` 稳定 id）
- `docs/specs/entity-fields.md`（字段与取值）

设计约束：
  1. **不改写数据**。校验器只读，任何"修正"都由作者在源数据里做。
  2. **一次报告全部问题**，不 fail-fast —— 改一轮跑一轮的代价比多读几行输出高。
  3. **报错稳定**。issue 顺序由遍历顺序决定，遍历前显式排序，避免同输入两次输出不同。
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass

# --- 取值域 ---------------------------------------------------------------
# 六轴：学科 / 岗位 / 行业 / 能力 / 主题 / 技术栈（SPEC-FND-002）
AXES = ("subject", "role", "industry", "ability", "topic", "stack")

# 骨架三轴（SPEC-TREE-003）。与上面的 `AXES` **不是一回事**：那个是六轴 —— 条目的
# 编目维度；这个是骨架目录的三条树根。两处都叫「轴」，读的人容易并成一处，
# 所以名字里带 SKELETON，用的时候看得出是哪一个。
SKELETON_AXES = ("discipline", "major", "occupation")

# 节点 id 形如 `{plugin_id}:{local_id}`，local 段可含 `/`（骨架 id 就是 `skeleton:major/050201`）。
# `@` 不在合法字符里 —— 这个字符留给「不是节点的东西」，一旦挂点写成 `@...`，
# 装配出来的父边就指向一个谁也没有的 id。
NODE_ID_RE = re.compile(r"^[a-z][a-z0-9-]*:[a-zA-Z0-9/_-]+$")

# 六要件：边界 / 证成 / 命题 / 关联 / How / Tacit（SPEC-FND-004）
REQUIREMENTS = ("boundary", "justification", "proposition", "relation", "how", "tacit")

# 三态（SPEC-PACK-009）：「不可外化」必须显式声明，不得用 null 表示
REQ_STATES = ("present", "missing", "not_externalizable")

# 三层：持久 / 视图 / 快消（SPEC-FND-003）
LAYERS = ("persistent", "view", "ephemeral")

# 项类型：陈述 / 程序 / 技能 / 默会（entity-fields §2）
ITEM_TYPES = ("declarative", "procedural", "skill", "tacit")

# 边类型：实线 = 强依赖 / 虚线 = 弱依赖 / 指向未知（entity-fields §3 · channel-table 第 6 通道）
EDGE_TYPES = ("strong", "weak", "unknown")

# 出处等级（entity-fields §5 §6）
AUTHORITY_LEVELS = ("L0", "L1", "L2", "L4")

# pack 内容五段 —— **作废形态**：目标形态是「清单 + 六段」（`SPEC-PACK-005`），
# 本管线尚未迁移，迁移时机见那一条的「迁移状态」段。
SEGMENTS = ("items", "edges", "schemes", "questions", "excerpts")

# 信封字段：只回答「这是哪个空间的哪一版」，不含构建时间戳
META_KEYS = ("space", "version")

SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
SPACE_ID_RE = re.compile(r"^[a-z][a-z0-9-]*$")
SEG_ID_RE = re.compile(r"^[a-z][a-z0-9-]*$")
ACCENT_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
VERSIONED_ID_RE = re.compile(r"@\d")


@dataclass(frozen=True)
class Issue:
    """一条校验失败。`where` 用「文件:段[id]」定位，便于直接跳到源数据。"""

    code: str
    where: str
    msg: str

    def __str__(self) -> str:
        return f"{self.code}  {self.where}  {self.msg}"


def _issue(code: str, where: str, msg: str) -> Issue:
    return Issue(code=code, where=where, msg=msg)


def _is_str(v) -> bool:
    return isinstance(v, str) and v != ""


# --- 读源 -----------------------------------------------------------------


def load_source(root: str) -> tuple[dict | None, dict[str, list | None], list[Issue]]:
    """读一个空间目录：`manifest.json` + 五段 json。缺失即报，不猜。"""
    issues: list[Issue] = []
    manifest_path = os.path.join(root, "manifest.json")
    manifest = None
    if not os.path.isfile(manifest_path):
        issues.append(_issue("E-MANIFEST-MISSING", "manifest.json", "空间目录必须含 manifest.json"))
    else:
        try:
            with open(manifest_path, encoding="utf-8") as f:
                manifest = json.load(f)
        except json.JSONDecodeError as exc:
            issues.append(_issue("E-JSON", "manifest.json", f"JSON 解析失败：{exc}"))
        else:
            if not isinstance(manifest, dict):
                issues.append(_issue("E-MANIFEST-FIELD", "manifest.json", "顶层必须是 object"))
                manifest = None

    segments: dict[str, list | None] = {}
    for name in SEGMENTS:
        path = os.path.join(root, f"{name}.json")
        if not os.path.isfile(path):
            segments[name] = None
            issues.append(
                _issue("E-SEGMENT-MISSING", f"{name}.json", "pack 五段缺段（旧形态，`SPEC-PACK-005` 的作废版）")
            )
            continue
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except json.JSONDecodeError as exc:
            segments[name] = None
            issues.append(_issue("E-JSON", f"{name}.json", f"JSON 解析失败：{exc}"))
            continue
        if not isinstance(data, list):
            segments[name] = None
            issues.append(_issue("E-SEGMENT-TYPE", f"{name}.json", "段必须是数组"))
            continue
        segments[name] = data

    return manifest, segments, issues


# --- manifest -------------------------------------------------------------


def _check_manifest(manifest: dict) -> list[Issue]:
    out: list[Issue] = []
    where = "manifest.json"

    for key in ("id", "name", "version", "sixAxis", "accent", "order"):
        if key not in manifest:
            out.append(_issue("E-MANIFEST-FIELD", where, f"缺必填字段 `{key}`"))

    space_id = manifest.get("id")
    if space_id is not None:
        if not _is_str(space_id):
            out.append(_issue("E-MANIFEST-FIELD", where, "`id` 必须是非空字符串"))
        elif not SPACE_ID_RE.match(space_id):
            out.append(
                _issue("E-MANIFEST-FIELD", where, f"`id` 须匹配 {SPACE_ID_RE.pattern}，实为 {space_id!r}")
            )

    if "name" in manifest and not _is_str(manifest["name"]):
        out.append(_issue("E-MANIFEST-FIELD", where, "`name` 必须是非空字符串"))

    if "version" in manifest:
        version = manifest["version"]
        # ⚠️ 不 strip：带了空白就是源数据错了。静默修正会让 pack 里的版本
        # 与 tag 名对不上，而 tag 是产物唯一指针。
        if not isinstance(version, str):
            out.append(_issue("E-VERSION-FORMAT", where, f"`version` 必须是字符串，实为 {type(version).__name__}"))
        elif not SEMVER_RE.match(version):
            out.append(
                _issue("E-VERSION-FORMAT", where, f"`version` 须为纯 semver，实为 {version!r}（不做 trim）")
            )

    six_axis = manifest.get("sixAxis")
    if six_axis is not None:
        if not isinstance(six_axis, dict):
            out.append(_issue("E-SIXAXIS", where, "`sixAxis` 必须是 object"))
        else:
            for axis, value in sorted(six_axis.items()):
                if axis not in AXES:
                    out.append(_issue("E-SIXAXIS", where, f"`sixAxis` 有一轴不在册：{axis!r}（六轴见 SPEC-FND-002）"))
                elif not _is_str(value):
                    out.append(_issue("E-SIXAXIS", where, f"`sixAxis.{axis}` 须为单值字符串（同轴单值是多选取 OR 的前提）"))

    accent = manifest.get("accent")
    if accent is not None and not (isinstance(accent, str) and ACCENT_RE.match(accent)):
        out.append(_issue("E-MANIFEST-FIELD", where, f"`accent` 须形如 #RRGGBB，实为 {accent!r}"))

    order = manifest.get("order")
    if order is not None and (isinstance(order, bool) or not isinstance(order, int)):
        out.append(_issue("E-MANIFEST-FIELD", where, f"`order` 须为整数，实为 {order!r}"))

    domains = manifest.get("domainIds")
    if domains is not None:
        if not isinstance(domains, list) or not all(_is_str(d) for d in domains):
            out.append(_issue("E-MANIFEST-FIELD", where, "`domainIds` 须为字符串数组"))
        elif len(set(domains)) != len(domains):
            out.append(_issue("E-MANIFEST-FIELD", where, "`domainIds` 有重复取值"))

    return out


# --- 树上的落点 -----------------------------------------------------------


def _check_attach(manifest: dict) -> list[Issue]:
    """载荷必须声明挂哪条轴、挂在哪个骨架节点下（`entity-fields` §1 `attach_to`）。

    **为什么这条要写成硬校验**：这两个字段缺了或写歪了，包照样装得出来、照样
    读得进客户端 —— 错的地方要等所有包装在一起建树才现形，而那时报的是
    「某轴有两条无父链」，指在子节点上，与真正写错的那一行隔着一整条装配链。
    这个函数的全部价值就是让错报在写错的那一行。

    `flattenDomains` 一并在这里查：它决定包顶层是一行还是多行，写歪了会让
    「域」这个层级凭空消失，而界面上只表现为「这个包的域不见了」。
    """
    out: list[Issue] = []
    where = "manifest.json"

    axis = manifest.get("axis")
    if axis is None:
        out.append(
            _issue("E-ATTACH-MISSING", where, "缺 `axis` —— 载荷必须声明挂在骨架的哪条轴上")
        )
    elif axis not in SKELETON_AXES:
        out.append(
            _issue("E-ATTACH-AXIS", where, f"`axis` 不在册：{axis!r}（{' / '.join(SKELETON_AXES)}）")
        )

    attach_to = manifest.get("attach_to")
    if attach_to is None:
        out.append(
            _issue("E-ATTACH-MISSING", where, "缺 `attach_to` —— 载荷必须声明挂在哪个骨架节点下")
        )
    elif not _is_str(attach_to):
        out.append(_issue("E-ATTACH-NOT-ID", where, "`attach_to` 必须是非空字符串，且是一个节点 id"))
    elif attach_to.startswith("@"):
        out.append(
            _issue(
                "E-ATTACH-NOT-ID",
                where,
                f"`attach_to` 写成了令牌：{attach_to!r}。它以 `@` 开头，而节点 id 形如 "
                "`{plugin_id}:{local_id}` —— 这类值不是任何包里的节点，挂上去就是悬空父边",
            )
        )
    elif not NODE_ID_RE.match(attach_to):
        out.append(
            _issue(
                "E-ATTACH-NOT-ID",
                where,
                f"`attach_to` 须为节点 id（形如 `{{plugin_id}}:{{local_id}}`），实为 {attach_to!r}",
            )
        )

    flat = manifest.get("flattenDomains")
    if flat is not None:
        if not isinstance(flat, dict):
            out.append(_issue("E-FLATTEN", where, "`flattenDomains` 必须是 object"))
        else:
            for key in ("slug", "name"):
                if not _is_str(flat.get(key)):
                    out.append(
                        _issue("E-FLATTEN", where, f"`flattenDomains.{key}` 必须是非空字符串")
                    )
            slug = flat.get("slug")
            if _is_str(slug) and not SEG_ID_RE.match(slug):
                out.append(
                    _issue(
                        "E-FLATTEN",
                        where,
                        f"`flattenDomains.slug` 须匹配 {SEG_ID_RE.pattern}，实为 {slug!r}",
                    )
                )
            tags = flat.get("tags")
            if tags is not None and (
                not isinstance(tags, list) or not all(_is_str(t) for t in tags)
            ):
                out.append(_issue("E-FLATTEN", where, "`flattenDomains.tags` 须为字符串数组"))

    return out


# --- items ----------------------------------------------------------------


def _check_items(items: list, space_id: str | None, manifest: dict) -> tuple[list[Issue], dict[str, list[str]]]:
    """返回 (issues, {item_id: sourceRefs})。sourceRefs 的交叉引用需等 excerpts
    读完后才能判，因此不在本函数内报错，也不往 item 里塞临时键（只读）。"""
    out: list[Issue] = []
    seen: dict[str, int] = {}
    domain_ids = set(manifest.get("domainIds") or [])
    refs_by_item: dict[str, list[str]] = {}

    for idx, item in enumerate(items):
        where = f"items.json[{idx}]"
        if not isinstance(item, dict):
            out.append(_issue("E-ITEM-FIELD", where, "item 必须是 object"))
            continue

        item_id = item.get("id")
        if not _is_str(item_id):
            out.append(_issue("E-ITEM-FIELD", where, "缺必填字段 `id`"))
        else:
            where = f"items.json[{item_id}]"
            if VERSIONED_ID_RE.search(item_id):
                # SPEC-PACK-008 / PACK-008 验收向量：`python/decorator@2.1.0`
                out.append(
                    _issue("E-ID-VERSIONED", where, "id 不得含版本号（升级后已学事件会全部指向旧 id，SPEC-FND-013）")
                )
            if space_id and not item_id.startswith(f"{space_id}/"):
                out.append(_issue("E-ID-FORMAT", where, f"id 必须以 `{space_id}/` 开头"))
            elif not re.match(r"^[a-z][a-z0-9-]*/[a-z][a-z0-9-]*$", item_id):
                out.append(_issue("E-ID-FORMAT", where, "id 形如 `<space>/<slug>`，小写字母、数字、连字符"))
            if item_id in seen:
                out.append(_issue("E-ID-DUP", where, f"id 重复（首次出现在 items.json[{seen[item_id]}]）"))
            else:
                seen[item_id] = idx

        # `sourceRefs` 也在这里守：客户端 `Item.fromJson` 把它当**必填**，
        # 省略不会让校验红，但会让整个空间在 `parsePack` 抛异常、界面上直接
        # 少一个根 —— 「校验绿、装不出来」是最坏的失败形态。允许空数组
        # （`[]` = 暂无出处），只禁止「这个键不存在」。
        for key in ("title", "sixAxis", "layer", "type", "requirements", "sourceRefs"):
            if key not in item:
                out.append(_issue("E-ITEM-FIELD", where, f"缺必填字段 `{key}`"))

        if "title" in item and not _is_str(item["title"]):
            out.append(_issue("E-ITEM-FIELD", where, "`title` 必须是非空字符串"))

        six_axis = item.get("sixAxis")
        if six_axis is not None:
            if not isinstance(six_axis, dict):
                out.append(_issue("E-SIXAXIS", where, "`sixAxis` 必须是 object"))
            else:
                for axis, value in sorted(six_axis.items()):
                    if axis not in AXES:
                        out.append(_issue("E-SIXAXIS", where, f"`sixAxis` 有一轴不在册：{axis!r}"))
                    elif not _is_str(value):
                        # 数组 = 同轴多值，会让「同轴多选取 OR」失去前提
                        out.append(_issue("E-SIXAXIS", where, f"`sixAxis.{axis}` 须为单值字符串"))

        layer = item.get("layer")
        if layer is not None and layer not in LAYERS:
            out.append(_issue("E-LAYER", where, f"`layer` 不在册：{layer!r}（{', '.join(LAYERS)}）"))

        item_type = item.get("type")
        if item_type is not None and item_type not in ITEM_TYPES:
            out.append(_issue("E-TYPE", where, f"`type` 不在册：{item_type!r}（{', '.join(ITEM_TYPES)}）"))

        reqs = item.get("requirements")
        if reqs is not None:
            if not isinstance(reqs, dict):
                out.append(_issue("E-REQ-STATE", where, "`requirements` 必须是 object"))
            else:
                missing = [k for k in REQUIREMENTS if k not in reqs]
                extra = [k for k in sorted(reqs) if k not in REQUIREMENTS]
                if missing:
                    out.append(_issue("E-REQ-KEY", where, f"六要件缺格：{', '.join(missing)}"))
                if extra:
                    out.append(_issue("E-REQ-KEY", where, f"六要件有多余键：{', '.join(extra)}"))
                for key in REQUIREMENTS:
                    if key not in reqs:
                        continue
                    state = reqs[key]
                    if state is None:
                        # 缺失 ≠ 不可外化：null 会让默会类项被判成「还没写」
                        out.append(
                            _issue(
                                "E-REQ-STATE",
                                where,
                                f"`requirements.{key}` 为 null；「还没写」用 missing，「本来就没有外部形态」用 "
                                f"not_externalizable（SPEC-PACK-009）",
                            )
                        )
                    elif state not in REQ_STATES:
                        # 与 null 分开报：一个是用错了表达方式，一个是值不在册
                        out.append(_issue("E-REQ-VALUE", where, f"`requirements.{key}` 不在三态内：{state!r}"))

        refs = item.get("sourceRefs")
        if refs is not None:
            if not isinstance(refs, list) or not all(_is_str(r) for r in refs):
                out.append(_issue("E-ITEM-FIELD", where, "`sourceRefs` 须为字符串数组"))
            elif _is_str(item_id):
                refs_by_item[item_id] = list(refs)

        domain = item.get("domainId")
        if domain is not None:
            if not _is_str(domain):
                out.append(_issue("E-ITEM-FIELD", where, "`domainId` 须为非空字符串"))
            elif domain_ids and domain not in domain_ids:
                out.append(_issue("E-DOMAIN", where, f"`domainId` 不在 manifest.domainIds 中：{domain!r}"))

        if "inScope" in item and not isinstance(item["inScope"], bool):
            out.append(_issue("E-ITEM-FIELD", where, "`inScope` 须为布尔"))

    return out, refs_by_item


# --- edges ----------------------------------------------------------------


def _check_edges(edges: list, item_ids: set[str]) -> list[Issue]:
    out: list[Issue] = []
    seen: dict[str, int] = {}
    pairs: dict[tuple[str, str], int] = {}

    for idx, edge in enumerate(edges):
        where = f"edges.json[{idx}]"
        if not isinstance(edge, dict):
            out.append(_issue("E-EDGE-FIELD", where, "edge 必须是 object"))
            continue

        edge_id = edge.get("id")
        if not _is_str(edge_id):
            out.append(_issue("E-EDGE-FIELD", where, "缺必填字段 `id`"))
        else:
            where = f"edges.json[{edge_id}]"
            if not SEG_ID_RE.match(edge_id):
                out.append(_issue("E-EDGE-FIELD", where, "edge id 须为小写字母 / 数字 / 连字符"))
            if edge_id in seen:
                out.append(_issue("E-ID-DUP", where, f"edge id 重复（首次出现在 edges.json[{seen[edge_id]}]）"))
            else:
                seen[edge_id] = idx

        src, dst = edge.get("from"), edge.get("to")
        if not _is_str(src):
            out.append(_issue("E-EDGE-FIELD", where, "缺必填字段 `from`"))
        if not _is_str(dst):
            out.append(_issue("E-EDGE-FIELD", where, "缺必填字段 `to`"))

        edge_type = edge.get("type")
        if edge_type is None:
            out.append(_issue("E-EDGE-FIELD", where, "缺必填字段 `type`"))
        elif edge_type not in EDGE_TYPES:
            out.append(_issue("E-EDGE-TYPE", where, f"`type` 不在册：{edge_type!r}（{', '.join(EDGE_TYPES)}）"))

        if _is_str(src) and item_ids and src not in item_ids:
            out.append(_issue("E-EDGE-REF", where, f"`from` 指向不存在的项：{src}"))
        if _is_str(dst) and item_ids and dst not in item_ids:
            # 「指向未知」是合法语义（虚线 = 弱依赖 / 指向未知），但必须显式声明
            if edge_type != "unknown":
                out.append(
                    _issue(
                        "E-EDGE-REF",
                        where,
                        f"`to` 指向不存在的项 {dst}；若这是「指向未知」，type 须为 unknown",
                    )
                )

        if _is_str(src) and _is_str(dst):
            if src == dst:
                out.append(_issue("E-CYCLE", where, f"自环：{src} -> {dst}"))
            pair = (src, dst)
            if pair in pairs:
                out.append(_issue("E-EDGE-DUP", where, f"边重复（首次出现在 edges.json[{pairs[pair]}]）"))
            else:
                pairs[pair] = idx

    return out


def find_cycles(edges: list) -> list[list[str]]:
    """返回所有**基本环**（每条环只报一次，起点取环上最小 id）。

    只沿合法边（两端都在集合内且非自环）走，保证报错指向真实数据问题。
    """
    adj: dict[str, list[str]] = {}
    for edge in edges:
        if not isinstance(edge, dict):
            continue
        src, dst = edge.get("from"), edge.get("to")
        if _is_str(src) and _is_str(dst) and src != dst:
            adj.setdefault(src, set()).add(dst)

    cycles: list[list[str]] = []
    seen_signatures: set[tuple[str, ...]] = set()
    color: dict[str, int] = {}
    stack: list[str] = []

    def dfs(node: str) -> None:
        color[node] = 1
        stack.append(node)
        for nxt in sorted(adj.get(node, ())):
            state = color.get(nxt, 0)
            if state == 0:
                dfs(nxt)
            elif state == 1:
                start = stack.index(nxt)
                ring = stack[start:]
                pivot = ring.index(min(ring))
                rotated = tuple(ring[pivot:] + ring[:pivot])
                if rotated not in seen_signatures:
                    seen_signatures.add(rotated)
                    cycles.append(list(rotated) + [rotated[0]])
        stack.pop()
        color[node] = 2

    for node in sorted(adj):
        if color.get(node, 0) == 0:
            dfs(node)

    return sorted(cycles)


# --- schemes --------------------------------------------------------------


def compute_inversions(nodes: list[str], edges: list) -> int:
    """`nodes` 相对 `⪯` 的逆序数：一条前置边在后继之后出现即计一次。

    只统计两端都在 `nodes` 里的边；逆序不禁止（`SPEC-PLAN-012`），
    但必须算出来以便 Planner 显式展示代价。
    """
    pos = {nid: i for i, nid in enumerate(nodes)}
    count = 0
    for edge in edges:
        if not isinstance(edge, dict):
            continue
        src, dst = edge.get("from"), edge.get("to")
        if src in pos and dst in pos and pos[src] > pos[dst]:
            count += 1
    return count


def _check_schemes(schemes: list, item_ids: set[str]) -> list[Issue]:
    out: list[Issue] = []
    seen: dict[str, int] = {}

    for idx, scheme in enumerate(schemes):
        where = f"schemes.json[{idx}]"
        if not isinstance(scheme, dict):
            out.append(_issue("E-SCHEME-FIELD", where, "scheme 必须是 object"))
            continue

        scheme_id = scheme.get("id")
        if not _is_str(scheme_id):
            out.append(_issue("E-SCHEME-FIELD", where, "缺必填字段 `id`"))
        else:
            where = f"schemes.json[{scheme_id}]"
            if scheme_id in seen:
                out.append(_issue("E-ID-DUP", where, f"scheme id 重复（首次出现在 schemes.json[{seen[scheme_id]}]）"))
            else:
                seen[scheme_id] = idx

        if not _is_str(scheme.get("name")):
            out.append(_issue("E-SCHEME-FIELD", where, "缺必填字段 `name`"))

        level = scheme.get("authorityLevel")
        if level is None:
            out.append(_issue("E-SCHEME-FIELD", where, "缺必填字段 `authorityLevel`"))
        elif level not in AUTHORITY_LEVELS:
            out.append(_issue("E-SCHEME-AUTH", where, f"`authorityLevel` 不在册：{level!r}"))

        nodes = scheme.get("nodes")
        if not isinstance(nodes, list):
            out.append(_issue("E-SCHEME-FIELD", where, "`nodes` 必须是数组"))
            continue
        if not nodes:
            out.append(_issue("E-SCHEME-FIELD", where, "`nodes` 不能为空（体系是一条有序路径）"))

        dup_nodes = sorted({n for n in nodes if isinstance(n, str) and nodes.count(n) > 1})
        if dup_nodes:
            out.append(_issue("E-SCHEME-DUP", where, f"`nodes` 有重复项：{', '.join(dup_nodes)}"))

        for node in nodes:
            if not _is_str(node):
                out.append(_issue("E-SCHEME-FIELD", where, "`nodes` 只能含字符串 id"))
            elif item_ids and node not in item_ids:
                out.append(_issue("E-SCHEME-NODE-REF", where, f"`nodes` 引用了不存在的项：{node}"))

    return out


# --- questions ------------------------------------------------------------


def _check_questions(questions: list, item_ids: set[str]) -> list[Issue]:
    """四字段见 `entity-fields.md` §4（`Question`）。加字段前先改那张表 ——
    `questions` 已计入 `SPEC-PACK-006` 的两次扩大，再扩要过「暂停」判据。
    """
    out: list[Issue] = []
    seen: dict[str, int] = {}

    for idx, question in enumerate(questions):
        where = f"questions.json[{idx}]"
        if not isinstance(question, dict):
            out.append(_issue("E-QUESTION-FIELD", where, "question 必须是 object"))
            continue

        qid = question.get("id")
        if not _is_str(qid):
            out.append(_issue("E-QUESTION-FIELD", where, "缺必填字段 `id`"))
        else:
            where = f"questions.json[{qid}]"
            if qid in seen:
                out.append(_issue("E-ID-DUP", where, f"question id 重复（首次出现在 questions.json[{seen[qid]}]）"))
            else:
                seen[qid] = idx

        for key in ("itemId", "prompt", "answer"):
            if not _is_str(question.get(key)):
                out.append(_issue("E-QUESTION-FIELD", where, f"缺必填字段 `{key}`"))

        item_id = question.get("itemId")
        if _is_str(item_id) and item_ids and item_id not in item_ids:
            out.append(_issue("E-QUESTION-REF", where, f"`itemId` 指向不存在的项：{item_id}"))

    return out


# --- excerpts -------------------------------------------------------------


def _check_excerpts(excerpts: list) -> tuple[list[Issue], set[str]]:
    """`excerpts` 段是 `SourceRef[]`（entity-fields §6）。摘录离线可读，带许可标记。"""
    out: list[Issue] = []
    seen: dict[str, int] = {}

    for idx, source in enumerate(excerpts):
        where = f"excerpts.json[{idx}]"
        if not isinstance(source, dict):
            out.append(_issue("E-EXCERPT-FIELD", where, "source 必须是 object"))
            continue

        sid = source.get("id")
        if not _is_str(sid):
            out.append(_issue("E-EXCERPT-FIELD", where, "缺必填字段 `id`"))
        else:
            where = f"excerpts.json[{sid}]"
            if sid in seen:
                out.append(_issue("E-ID-DUP", where, f"source id 重复（首次出现在 excerpts.json[{seen[sid]}]）"))
            else:
                seen[sid] = idx

        if not _is_str(source.get("name")):
            out.append(_issue("E-EXCERPT-FIELD", where, "缺必填字段 `name`"))
        if not _is_str(source.get("version")):
            out.append(_issue("E-EXCERPT-FIELD", where, "缺必填字段 `version`（源自身的版本）"))

        level = source.get("authorityLevel")
        if level is None:
            out.append(_issue("E-EXCERPT-FIELD", where, "缺必填字段 `authorityLevel`"))
        elif level not in AUTHORITY_LEVELS:
            out.append(_issue("E-EXCERPT-FIELD", where, f"`authorityLevel` 不在册：{level!r}"))

        segments = source.get("segments")
        if not isinstance(segments, list) or not segments:
            out.append(_issue("E-EXCERPT-FIELD", where, "`segments` 必须是至少一条的数组"))
            continue
        for seg_idx, seg in enumerate(segments):
            if not isinstance(seg, dict):
                out.append(_issue("E-EXCERPT-FIELD", where, f"`segments[{seg_idx}]` 必须是 object"))
                continue
            for key in ("text", "locator", "license"):
                if not _is_str(seg.get(key)):
                    out.append(
                        _issue(
                            "E-EXCERPT-FIELD",
                            where,
                            f"`segments[{seg_idx}]` 缺 `{key}`（离线可读须带出处与许可）",
                        )
                    )

    return out, set(seen)


# --- 入口 -----------------------------------------------------------------


def validate(manifest: dict | None, segments: dict[str, list | None]) -> list[Issue]:
    """校验源数据。返回**全部** issue，按 code 分组后排序。"""
    issues: list[Issue] = []
    if manifest is None:
        return issues

    issues.extend(_check_manifest(manifest))
    issues.extend(_check_attach(manifest))
    space_id = manifest.get("id") if _is_str(manifest.get("id")) else None

    items = segments.get("items") or []
    edges = segments.get("edges") or []
    schemes = segments.get("schemes") or []
    questions = segments.get("questions") or []
    excerpts = segments.get("excerpts") or []

    item_issues, refs_by_item = _check_items(items, space_id, manifest)
    issues.extend(item_issues)
    item_ids = {it["id"] for it in items if isinstance(it, dict) and _is_str(it.get("id"))}

    issues.extend(_check_edges(edges, item_ids))
    for ring in find_cycles(edges):
        issues.append(_issue("E-CYCLE", "edges.json", f"前提边必须无环（SPEC-FND-005）：{' -> '.join(ring)}"))

    # PACK-001 验收向量：只含 items 无 edges 的包应被拒 —— 没有独立 ⪯ 就不构成
    # 独立空间，该降为上位空间内的「域」。这条不能只看文件在不在，要看是否有边。
    if segments.get("edges") is not None and not edges:
        issues.append(
            _issue(
                "E-SPACE-NO-ORDER",
                "edges.json",
                "空边集：缺独立前提偏序，按 SPEC-PACK-001 应降为域而非独立成包",
            )
        )

    issues.extend(_check_schemes(schemes, item_ids))
    issues.extend(_check_questions(questions, item_ids))

    excerpt_issues, source_ids = _check_excerpts(excerpts)
    issues.extend(excerpt_issues)

    # sourceRefs 的交叉引用要等 excerpts 读完才能判
    for item_id, refs in sorted(refs_by_item.items()):
        for ref in refs:
            if source_ids and ref not in source_ids:
                issues.append(
                    _issue("E-SOURCEREF", f"items.json[{item_id}]", f"`sourceRefs` 指向不存在的源：{ref}")
                )

    # 排序：同 code 聚在一起，便于一次读完一类问题
    return sorted(issues, key=lambda i: (i.code, i.where, i.msg))


def check_pack_object(pack: dict, expected_version: str | None = None) -> list[Issue]:
    """校验**已构建**的 pack.json：段集合与 `meta` 信封。

    这一层不重复字段级校验（产物由源数据而来，源已校验过），只守两件
    构建可能破坏的事：① 段没多也没少 ② `meta.version` 与源 `version` 逐字相同。
    """
    out: list[Issue] = []

    keys = set(pack)
    allowed = set(SEGMENTS) | {"meta"}
    for extra in sorted(keys - allowed):
        # SPEC-PACK-007：不得新增 notes 段（模板走平台层声明式定义）
        out.append(_issue("E-PACK-EXTRA-KEY", "pack.json", f"pack 不得出现 `{extra}` 段（SPEC-PACK-007）"))
    for missing in sorted(allowed - keys):
        out.append(_issue("E-PACK-MISSING-KEY", "pack.json", f"pack 缺 `{missing}`"))

    meta = pack.get("meta")
    if not isinstance(meta, dict):
        out.append(_issue("E-META-FIELD", "pack.json", "`meta` 必须是 object"))
        return out

    for extra in sorted(set(meta) - set(META_KEYS)):
        # 时间戳会让同一 commit 两次构建 byte 不等
        out.append(_issue("E-META-EXTRA-KEY", "pack.json", f"`meta` 只允许 {META_KEYS}，出现 `{extra}`"))
    for missing in META_KEYS:
        if missing not in meta:
            out.append(_issue("E-META-FIELD", "pack.json", f"`meta` 缺 `{missing}`"))

    version = meta.get("version")
    if expected_version is not None and version != expected_version:
        out.append(
            _issue(
                "E-META-VERSION",
                "pack.json",
                f"`meta.version` = {version!r} 与源 manifest 的 {expected_version!r} 不一致（须原样透传）",
            )
        )
    if isinstance(version, str) and not SEMVER_RE.match(version):
        out.append(_issue("E-META-VERSION", "pack.json", f"`meta.version` 不是纯 semver：{version!r}"))

    return out
