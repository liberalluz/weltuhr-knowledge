# docs —— agent 入口

本目录的**约定、边界与判据**。目录分工以 [`README.md`](README.md) §一 为准，**本文件不复制**。

## 路径基准

本文件内所有相对路径**以本目录（`docs/`）为基准**。

## 职责边界

- **负责**：设计规格（`design/`）· 参考层横切表（`reference/`）· 交付物（`deliverables/`）· 操作指南（`guides/`）· 架构决策（`adr/`）
- **不负责**：客户端实现约定（→ `app/AGENTS.md`）· 服务端实现约定（→ `server/AGENTS.md`）· 内容包与构建（→ `content/AGENTS.md`）· 部署与 CI（→ `infra/AGENTS.md`）

## 落点判据

| 要写的是 | 落哪 |
|---|---|
| 是什么 / 为什么 | `design/` 或 `adr/` |
| 多少次 / 哪些值 | `reference/` |
| 怎么操作 | `guides/` |
| 对外交付、需签字、需版号 | `deliverables/` |

## 红线

- **交付物先建文件，再写内容**。不得「某份还没建，先写进 `deliverables/README.md`」—— 那个降级会在补齐时留下两份事实源。正文可以是「待填」。
- **记录类不追溯补录**。`DPMR` / `STR` 记录的是「当时确实如此」，事后补写会让证据退化为叙述。判据：这份文档在**记录一次已发生的事**，还是在**描述当前应当如此**？前者不补，后者可补。
- **基线只在 `SCMP` 登记**。`deliverables/README.md` 只保留编号与日期速览，完整内容只此一处。
- **活文档不设版号**。`design/` `reference/` `guides/` `adr/` 的更新时间以 `git log` 为准，**不手写「最后更新」头** —— 手写头会变成第二份会过期的记录。
- **引用不复制**。同一规则只在唯一权威处展开，其余位置写「见 XX」。数值只在 `reference/` 维护。
- **骨架文件的填充时点写在文件头**，不得因为「顺手能写」就提前填 —— 时点没到之前写出来的内容只是猜测，而且会被下游当成已定事实。
- **验收必须可观测**。写不出可观测断言的条目，说明该条没想清楚；不得以「实现里写了」充当验收。

## 交付物导航

| 段 | 内容 | 已写实 |
|---|---|---|
| [`deliverables/01-plan/`](deliverables/01-plan/) | 计划类 7 份 | `SDP` §4 计划表 · `SCMP` §三 基线 · `DPMR` 前史 · 其余骨架 |
| [`deliverables/02-requirements/`](deliverables/02-requirements/) | 需求类 5 份 | `SRS` 已含 `v0.1.0` 切片（128 / 171）与归属全量 |
| [`deliverables/03-design/`](deliverables/03-design/) | 设计类 4 份 | `SDD` 分章映射 · 其余骨架 |
| [`deliverables/04-test/`](deliverables/04-test/) | 测试类 3 份 | `STP` 分层与判据 · `STR` 不追溯声明 · `STD` 编号规则 |
| [`deliverables/05-delivery/`](deliverables/05-delivery/) | 交付类 5 份 | 全为骨架 |
| [`deliverables/06-report/`](deliverables/06-report/) | 总结 1 份 | 骨架 |

清单与命名的唯一权威处 = [`deliverables/README.md`](deliverables/README.md) §一。
