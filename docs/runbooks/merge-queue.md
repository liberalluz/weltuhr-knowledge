# Merge queue（C14）

> **状态**：deferred（未启用）。当前按“直接合并 + 串行批次”运行，等并发真的出现再按本文开启。

## 为什么现在不开

- 当前只有两名维护者，PR 基本逐笔合并；
- `batch merge` 直接调用 `gh pr merge --squash`，成功后立即写 `merge.json`；
- merge queue 会把 PR 先放进队列，状态从“可合并”变成“排队中”，`merge.py` / `batch merge` 的“已合并”判断、审计记录和 evidence 都要改；
- 没有并发时开启，只会增加等待和状态分支，不会减少冲突。

## 触发条件

满足任一条再开启：

- 同时有 **≥3 个 ready PR**，且合并时反复出现 base 更新冲突；
- 单日合并 **≥3 笔**，`batch merge` 经常因 `mergeable=UNKNOWN` / `CLEAN` 抖动需要重试；
- 新增维护者后开始并行提 PR；
- C12 周报的 `lead` 或 rework 显示合并等待明显变长。

## 开启步骤

1. **ruleset 增加 `merge_queue` 规则**（仍保留现有 required checks / 1 approval / code-owner / conversation resolution）：

   ```json
   {
     "type": "merge_queue",
     "parameters": {
       "check_response_timeout_minutes": 60,
       "grouping_strategy": "ALLGREEN",
       "max_entries_to_build": 5,
       "max_entries_to_merge": 5,
       "merge_method": "SQUASH",
       "min_entries_to_merge": 1,
       "min_entries_to_merge_wait_minutes": 5
     }
   }
   ```

2. **改 `batch merge`**：
   - 检测 PR 是否进入队列；
   - 用 GraphQL `enqueuePullRequest` 或等价 API 入队；
   - 轮询到 `MERGED` 后才写 `merge.json`；
   - 超时/被踢出队列时返回非零，不写成功记录。

3. **改 `merge.py`**：
   - 队列模式下 `mergeable` 不等于“已合并”；
   - 不做 `gh pr merge --squash` 的直接假设；
   - 保留 checks / approval / head sha 的前置校验。

4. **测试**：
   - 两个 PR 同时 ready，先后入队，均合并；
   - 队列期间 base 更新，仍能自动重建；
   - 一个 PR 被踢出，`batch merge` 报错且不写 `merge.json`；
   - required check 失败时队列不合并。

5. **回滚**：
   - 删除 ruleset 的 `merge_queue` 规则；
   - `batch merge` 恢复直接合并分支；
   - 保留已合并 PR 的 `merge.json`，不追改历史。

## 验收

- 队列状态下 `batch status` 不会把 queued 误报成 merged；
- `merge.json` 只在真正 MERGED 后出现；
- 两个并发 PR 不再互相把对方变成 `BEHIND`；
- C12 周报能区分 queued 时间与 merged 时间。

## 关联

- C10 ruleset：`main-protection`
- C12 指标：`infra/tool/metrics/pr_metrics.py`
- 批次合并：`infra/tool/batch/merge.py` / `batch.py merge`
