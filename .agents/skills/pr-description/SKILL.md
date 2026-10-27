---
name: pr-description
description: 生成并校验 PR 正文，保证九节齐全、N/M/K 与 diff 对账、证据可核对。
whenToUse: 开 PR、改 PR 正文、或正文被 repo-hygiene 判红时。
metadata:
  owner: liberal
---

# pr-description

## Owner

- Owner: `liberal`
- 适用：全部 PR；判据见 `docs/specs/git-conventions.md` §4.1

## 必填骨架

```text
## 变更摘要
## 影响面（平台组 / 类型 / 兼容与回滚 / 技术栈表）
## 自审留痕（基线 / 改动面 / 版号 / 反证 / 如实登记）
## 验证（命令与输出 / 测试设计 / 未验）
## UI 证据
## 交付物
## AI 参与（级别 / 生成 / 人核）
## 关联（八类封闭集）
## 评审提示
```

## 规则

- `N` 必须等于真实 diff 的路径数；不要手写估计值。
- `影响面` 三字段常驻：`平台` 按平台一行（`<平台>：已测 —— 证据` / `<平台>：未测 —— 原因与谁验`）· `类型` · `兼容与回滚`。`技术栈` 仅当 diff 跨 ≥2 栈时出现（组名行不写值，表挂节末，四栈各一行，与字段行成套）；跨 0 或 1 栈整组不写。
- `自审留痕` 五行：`反证` 字段行可带一句总述，逐条尝试下沉；`如实登记` 不设总述。
- `改动面` 条目写「做了什么：路径与依据」，冒号前不得只放路径；`未动 0 处` 时不留「未动」条目。
- 验证贴真实终端输出；没跑的写「未验」，不要写「应该通过」。
- `关联` 只列有锚点的类，缺的类整行不出现；PR / issue 号写显示链接。
- 不写 `- [ ]`。
- 优先用生成器，不手抄：

```bash
python3 infra/tool/batch/batch.py pr --batch <id> --base main
# 审阅 .batch/<id>/pr-body.md 后
python3 infra/tool/batch/batch.py pr --batch <id> --base main --create --yes
```

## 示例

`C17` 的正文由 `batch pr` 生成，`改动面 N` 与真实 diff 对账；技术栈表四行由生成器补。

## 自检

```bash
bash .githooks/pr-body --file <body.md> --diff-base origin/main
python3 -B infra/tool/batch/skill_lint.py .agents/skills/pr-description/SKILL.md
```
