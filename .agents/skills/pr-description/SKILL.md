---
name: pr-description
description: 生成并校验 v2 PR 正文，保证 N/M/K、验证输出与未验项可核对。
whenToUse: 开 PR、改 PR 正文、或正文被 repo-hygiene 判红时。
metadata:
  owner: liberal
---

# pr-description

## Owner

- Owner: `liberal`
- 适用：`#193+` 的 v2 正文；旧 PR 不追改。

## 必填骨架

```text
## 变更摘要
## 影响面（平台 / 已测 / 未测 / 类型 / 兼容与回滚）
## 自审留痕（基线 / N-M-K / 版号 / 反证 / 如实登记）
## 验证（命令与真实输出 / 测试设计 / 未验）
## UI 证据
## 交付物
## AI 参与（级别 / 生成 / 人核）
## 关联
## 评审提示
```

## 规则

- `N` 必须等于真实 diff 的路径数；不要手写估计值。
- `M` 是语义项数；跨 `app` / `server` / `content` / `infra` 中 ≥2 个技术栈时，补「模块 / 是否改动 / 说明」三列表。
- 验证贴真实终端输出；没跑的写“未验”，不要写“应该通过”。
- 不写 `- [ ]`；不用裸 `#123`，PR 号必须显示链接。
- 优先用生成器，不手抄：

```bash
python3 infra/tool/batch/batch.py pr --batch <id> --base main
# 审阅 .batch/<id>/pr-body.md 后
python3 infra/tool/batch/batch.py pr --batch <id> --base main --create --yes
```

## 示例

C8 的正文由 `batch pr` 生成，`改动面 N=4` 与真实 diff 对账；`app + infra` 跨栈表由生成器补。

## 自检

```bash
bash .githooks/pr-body --file <body.md> --diff-base origin/main --pr-number 0
python3 -B infra/tool/batch/skill_lint.py .agents/skills/pr-description/SKILL.md
```
