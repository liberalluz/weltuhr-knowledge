#!/usr/bin/env python3
"""抓取《中华人民共和国职业分类大典（2022 年版）》官方在线系统。

出处：技能人才评价工作网 · 职业分类系统（`http://osta.mohrss.gov.cn/career`），
接口 `baseURL = /api`，两级取值：

  GET /api/client/get/tree                      —— 大类 → 中类 → 小类（三级一次取回）
  GET /api/client/subordinate/data?careerCode=…&versionId=…
                                                —— 该节点的直接下级（小类 → 细类）

按 `docs/specs/skeleton-catalog.md` §六 步骤 1 的已裁方案 `(A)` 执行：官方在线系统
逐级抓取，**只抓不转** —— 原始响应逐字落 `content/skeleton/source/`，字段重命名、
槽位映射、`id` / `path` 生成一律在 `extract_occupation.py`（步骤 2）做。
若边抓边转，条目数对不上时无从判断是漏抓还是抽错。

退出码：0 成功 · 1 有用例失败（已写部分产物）· 2 参数错。

用法：
    python tools/fetch_occupation.py                 # 增量抓取（缓存命中即跳过）
    python tools/fetch_occupation.py --force         # 忽略缓存重抓
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request

BASE = "http://osta.mohrss.gov.cn/api"
TREE_EP = "/client/get/tree"
SUB_EP = "/client/subordinate/data"
UA = {"User-Agent": "Mozilla/5.0 (compatible; weltuhr-skeleton-fetch/1.0)"}
RETRIES = 3


def fetch(path: str, params: str = "") -> dict:
    """取一个 JSON 响应，失败重试 RETRIES 次。"""
    url = f"{BASE}{path}{params}"
    last = None
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            if payload.get("code") != 200:
                raise RuntimeError(f"响应码 {payload.get('code')}: {payload.get('msg')}")
            return payload
        except (urllib.error.URLError, TimeoutError, OSError, RuntimeError) as exc:
            last = exc
            if attempt < RETRIES:
                time.sleep(1.5 * attempt)
    raise RuntimeError(f"{path} 抓取失败：{last}")


def load_cache(path: str) -> dict | None:
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as fh:
                return json.load(fh)
        except (OSError, json.JSONDecodeError):
            return None
    return None


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)  # content/

    parser = argparse.ArgumentParser(description="职业分类大典（2022）在线系统抓取")
    parser.add_argument(
        "--out",
        default=os.path.join(root, "skeleton", "source", "occupation-2022-osta.json"),
        help="原始响应落点（默认 content/skeleton/source/occupation-2022-osta.json）",
    )
    parser.add_argument(
        "--cache",
        default=os.path.join(tempfile.gettempdir(), "weltuhr-occ-cache"),
        help="逐节点缓存目录（可断点续跑；不属产物，默认系统临时目录）",
    )
    parser.add_argument("--delay", type=float, default=0.12, help="两次请求的间隔秒")
    parser.add_argument("--force", action="store_true", help="忽略缓存重抓")
    parser.add_argument(
        "--retrieved", default=datetime.date.today().isoformat(), help="抓取日期"
    )
    args = parser.parse_args()

    cache_dir = os.path.normpath(args.cache)
    os.makedirs(cache_dir, exist_ok=True)

    def log(msg: str) -> None:
        print(msg, flush=True)

    # ---- 1. 三级树 ----
    tree_cache = os.path.join(cache_dir, "tree.json")
    tree = None if args.force else load_cache(tree_cache)
    if tree is None:
        log("抓取三级树 …")
        tree = fetch(TREE_EP)
        with open(tree_cache, "w", encoding="utf-8") as fh:
            json.dump(tree, fh, ensure_ascii=False)
    body = tree["body"]

    lvl1 = body
    lvl2 = [n for b in body for n in b.get("children") or []]
    lvl3 = [n for m in lvl2 for n in m.get("children") or []]
    log(f"三级树：大类 {len(lvl1)} · 中类 {len(lvl2)} · 小类 {len(lvl3)}")

    # ---- 2. 逐个三级节点取下级（细类） ----
    sub: dict[str, list] = {}
    fails: list[tuple[str, str]] = []
    t0 = time.time()
    cached = 0
    for i, node in enumerate(lvl3, 1):
        code = node["careerCode"]
        vid = node["versionId"]
        node_cache = os.path.join(cache_dir, f"{code}.json")
        payload = None if args.force else load_cache(node_cache)
        if payload is not None:
            cached += 1
        else:
            try:
                payload = fetch(SUB_EP, f"?careerCode={code}&versionId={vid}")
                with open(node_cache, "w", encoding="utf-8") as fh:
                    json.dump(payload, fh, ensure_ascii=False)
            except RuntimeError as exc:
                fails.append((code, str(exc)))
                continue
            time.sleep(args.delay)
        sub[code] = payload["body"]
        if i % 25 == 0 or i == len(lvl3):
            log(
                f"  {i}/{len(lvl3)}  缓存命中 {cached}  失败 {len(fails)}"
                f"  用时 {time.time() - t0:.0f}s"
            )

    leaves = [n for v in sub.values() for n in v]
    log(f"细类合计 {len(leaves)}")

    # ---- 3. 落原始响应 ----
    out = {
        "meta": {
            "axis": "occupation",
            "catalog": "中华人民共和国职业分类大典（2022 年版）",
            "publisher": "人力资源社会保障部",
            "system": "技能人才评价工作网 · 职业分类系统",
            "page": "http://osta.mohrss.gov.cn/career",
            "endpoints": {"tree": TREE_EP, "subordinate": SUB_EP},
            "versionId": body[0]["versionId"] if body else None,
            "retrieved": args.retrieved,
            "envelope": {"code": tree.get("code"), "msg": tree.get("msg")},
            "requests": {"tree": 1, "subordinate": len(sub)},
            "counts": {
                "group": len(lvl1),
                "galaxy": len(lvl2),
                "cluster": len(lvl3),
                "star": len(leaves),
            },
            "failures": [{"careerCode": c, "error": e} for c, e in fails],
        },
        "tree": body,
        "subordinate": sub,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    # newline="\n" 不可省：文本模式在 Windows 上会把 \n 译成 \r\n，而 .gitattributes
    # 规定 *.json eol=lf ⇒ 入库内容与工作区字节不同，`source.sha256` 立刻对不上。
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
    size = os.path.getsize(args.out)
    log(f"写入 {args.out}（{size:,} B）")

    if fails:
        log(f"[warn] {len(fails)} 个节点抓取失败，重跑本脚本可续抓")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
