# ADR-0012：文档治理以基线为准，不以每笔 PR 为准

> **状态**：accepted（DOC-1）
> **日期**：2026-10-29
> **范围**：`docs/`、受控五份、SDP、外仓 records、PR/批次粒度
> **关联**：ADR-0009（交付物解散）、ADR-0011（`specs/controlled/`）

## 背景

当前文档体系同时存在三种成本：

1. 五份受控文档（`SCMP` `SRS` `SDD` `STP` `STD`）按每笔 PR 维护版号、头部与历史表；
2. 外仓 `process/sdp.md` 每批更新，累计 61 条修订；
3. `records/` 的 DPMR/STR 是持续追加的活记录，却被放进已冻结批次继续修改。

结果是同一笔变更在 PR 正文、SCMP 历史、STD/STP 历史、SDP 修订里重复记录 4–5 次；固定开销大于变更本身。

同时，PR 粒度不稳定：

- 一个 batch 可拆 4–8 个 PR；
- 多个“笔”也可压进 1 个 PR。

这使卡片的 scope/evidence 与 PR 的评审单位不一致。

## 决策

### 1. Batch = 一个 PR = 一个行为

- 一个 batch 只做一个可独立合入/回滚的行为；
- 一个 milestone 可以包含多个 batch；
- 历史 batch 不重排编号；新 batch 按此执行；
- 纯机械重构可多文件，但不得夹带行为变化；
- docs 批次、记录批次、发布批次分开。

### 2. 受控文档按基线升版，不按 PR 升版

- `specs/controlled/` 五份继续保留；
- 版号只在基线/发布（`BL-*`、`vX.Y.Z`）时递增；
- 日常 PR 不改版号、不加历史行、不改 `SCMP §5.1`；
- `SCMP` 只记录基线与策略；日常变更由 git/PR 追溯；
- 旧版号历史冻结，不重写；新策略只向前生效。

### 3. SDP 只写计划，进度不写 SDP

- SDP 留外仓 `process/sdp.md`（F5，可改）；
- 只写目标、范围、里程碑、出口判据、角色、质量/风险策略、变更控制；
- 进度写 `records/live/` 或生成报告；
- SDP 只在里程碑/计划变更时修改，不按批次修改；
- 正式签字/基线快照放 `process/snapshots/`。

### 4. records 分 live / frozen

- DPMR、STR 等持续追加的记录放 `records/live/`；
- live 只追加，不改旧节；
- 验收/交付时复制到 `records/<YYYY-MM>-<批次>/`，冻结后不改；
- 7 列索引只登记冻结批次，不登记 live。

### 5. 外仓是记录与资产仓，不是第二套工程文档

- 外仓保留：`records/` `legal/` `product/` `design/` `process/` `business/`；
- 外仓不复制：`SRS` `SDD` `STP` `STD` `SCMP`；
- 主仓不反向链接外仓；主仓只写纯文本指认（仓外，需另行检出）；
- 公开法务/商品文案按 F2 留外仓；只有代码耦合的手册源回 `docs/`。

### 6. docs_impact

批次卡增加：

```text
docs_impact: none | living | controlled
```

- `none`：不碰 controlled；用户可感变化写 `changelog.d/`；
- `living`：同 PR 更新 `specs/` / `decisions/` / `runbooks/`；
- `controlled`：进入 docs 批次，按基线统一更新。

## 后果

- 代码 PR 默认不改受控文档；
- PR 正文只写人能判断的内容；
- 文档数字/版号由 `docs reconcile` 对账；
- 文档历史从“每笔账本”回到 git/PR/ADR；
- records 真正可审计；
- SDP 不再成为第二份进度报告。

## 不做什么

- 不删除受控五份；
- 不重写旧版号历史；
- 不把 records/合同/设计源并进公开代码仓；
- 不把 SDP 迁进主仓 `docs/`；
- 不用每笔 PR 维护 SCMP 历史。
