# docs —— agent 入口

本目录的**约定、边界与判据**。目录分工以 [`README.md`](README.md) §一 为准，**本文件不复制**。

## 路径基准

本文件内所有相对路径**以本目录（`docs/`）为基准**。

## 职责边界

- **负责**：设计规格与横切表（`specs/`）· 上游论证（`intent/`）· 交付物（`deliverables/`）· 操作手册（`runbooks/`）· 架构决策（`decisions/`）
- **不负责**：客户端实现约定（→ `app/AGENTS.md`）· 服务端实现约定（→ `server/AGENTS.md`）· 内容包与构建（→ `content/AGENTS.md`）· 部署与 CI（→ `infra/AGENTS.md`）

## 落点判据

| 要写的是 | 落哪 |
|---|---|
| 是什么 / 为什么 | `specs/` 或 `decisions/` |
| 多少次 / 哪些值 | `specs/` |
| 怎么操作 | `runbooks/` |
| 对外交付、需签字、需版号 | `deliverables/` |

## 红线

- **交付物先建文件，再写内容**。不得「某份还没建，先写进 `deliverables/README.md`」—— 那个降级会在补齐时留下两份事实源。正文可以是「待填」。
- **记录类不追溯补录**。`DPMR` / `STR` 记录的是「当时确实如此」，事后补写会让证据退化为叙述。判据：这份文档在**记录一次已发生的事**，还是在**描述当前应当如此**？前者不补，后者可补。
- **基线只在 `SCMP` 登记**。`deliverables/README.md` 只保留编号与日期速览，完整内容只此一处。
- **活文档不设版号**。`specs/` `intent/` `runbooks/` `decisions/` 的更新时间以 `git log` 为准，**不手写「最后更新」头** —— 手写头会变成第二份会过期的记录。
- **引用不复制**。同一规则只在唯一权威处展开，其余位置写「见 XX」。数值只在 `specs/` 维护。
- **骨架文件的填充时点写在文件头**，不得因为「顺手能写」就提前填 —— 时点没到之前写出来的内容只是猜测，而且会被下游当成已定事实。
- **验收必须可观测**。写不出可观测断言的条目，说明该条没想清楚；不得以「实现里写了」充当验收。

## 译本规范

**中文是唯一事实源**，英文是默认展示语言。**库内文档**一律 `中文原文 + 各语言译本`，译本不得成为第二事实源；**对外四份除外** —— 只出一份英文，见下表「对外四份」。

| 项 | 规则 |
|---|---|
| 命名 | `<原名>.<lang>.md` —— `README.zh-CN.md` · `SDP-软件开发计划.en.md`。**原文保留 `<原名>.md`**，不加后缀 |
| 语言码 | `zh-CN` `en` `de` `it` `ja` `fr`（BCP 47）。**简体固定写 `zh-CN`，不写裸 `zh`** —— `zh` 是宏语言码、不区分简繁；将来加繁体用 `zh-TW`。取值与 `.swe-init.json` 的 `docsLocale.supported` 一致 |
| 对外四份 | **只出一份、语言统一英文**（账本 `docsLocale.external = en`）：根 [`README.md`](../README.md)（首页渲染）· [`.github/CONTRIBUTING.md`](../.github/CONTRIBUTING.md)（新 issue / PR 界面自动链接）· [`.github/SECURITY.md`](../.github/SECURITY.md)（Security 页 policy）· [`.github/CONTRIBUTING.ai.md`](../.github/CONTRIBUTING.ai.md)（AI 参与准入）。**不出译文** —— 治理、安全与准入三处措辞不一致会引发歧义 |
| 落点 | 译本**与其中文原文同目录**：根 README 的五份译本即在仓根，中文原文为 [`README.zh-CN.md`](../README.zh-CN.md)；其余文档 → 与原文同目录。**`.github/` 下不出译文**（见上「对外四份」） |
| 切换条 | `English · 简体中文 · Deutsch · Italiano · 日本語 · Français` 固定顺序，**当前语言加粗不设链接**，置于 `# 标题` 之下 |
| 溯源行 | 译本头部第二行写 `> Translation of <指向中文原文的链接> · <日期> · the Chinese version is authoritative.`（措辞按各语言自写，格式照此）。**不写 commit sha** —— 提交前不可知，写了必然立刻误报 |
| 链接 | 目标已有译本 ⇒ 指向同名译本；目标尚无译本 ⇒ 指向中文原文。**不指向其他译本** |
| 不译 | `AGENTS.md`（两套语言 = 两套规则源）· `LICENSE` · `NOTICE`（法律文本） |
| 完整性 | **中文原文不得删除，译本不得单独存在** —— `check_s0` 只判前缀存在，删了中文会静默通过 |

**已落译本**：仓根 `README.de.md` / `README.fr.md` / `README.it.md` / `README.ja.md` / `README.zh-CN.md` 五份（中文原文为 `README.zh-CN.md`）；**`.github/` 三份不出译文**（见上「对外四份」）。其余 57 份文档的译本**等首个版本发布后统一做**。

## 交付物导航

| 段 | 内容 | 已写实 |
|---|---|---|
| [`deliverables/01-plan/`](deliverables/01-plan/) | 计划类 7 份 | `SDP` §4 计划表 · `SCMP` §三 基线 · `DPMR` 前史 · 其余骨架 |
| [`deliverables/02-requirements/`](deliverables/02-requirements/) | 需求类 5 份 | `SRS` 已含 `v0.1.0` 切片（**141 / 203**）与归属全量。⚠️ 其中 `ACC` 12 条随 `ADR-0005` 决策 6 失效（`P1` 无登录、无服务端），待 `SRS` 清偿 |
| [`deliverables/03-design/`](deliverables/03-design/) | 设计类 4 份 | `SDD` 分章映射 · 其余骨架 |
| [`deliverables/04-test/`](deliverables/04-test/) | 测试类 3 份 | `STP` 分层与判据 · `STR` 不追溯声明 · `STD` 编号规则 |
| [`deliverables/05-delivery/`](deliverables/05-delivery/) | 交付类 5 份 | 全为骨架 |
| [`deliverables/06-report/`](deliverables/06-report/) | 总结 1 份 | 骨架 |

清单与命名的唯一权威处 = [`deliverables/README.md`](deliverables/README.md) §一。
