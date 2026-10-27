# Acceptance checklist (C13)

Read-only. Use with `verifier`; do not edit the batch to make an item pass.

## Scope

- [ ] `card.yaml` 的 goal / acceptance 能一句话复述
- [ ] `scope.json` 的 allowed/forbidden 能复述
- [ ] `git diff --name-only <base>...HEAD` 的每条路径都能落到 allowed
- [ ] 没有命中 forbidden / 流程文件（除非是 process 批次）
- [ ] card / scope 的 approval hash 都有效

## Evidence

- [ ] `evidence.log` 有 `RESULT: PASS`
- [ ] 每条命令与退出码可读，不是只写“通过”
- [ ] 失败/跳过的步骤被明确记录
- [ ] 没有把“未运行”写成“已验证”

## PR

- [ ] `headRefOid` 是当前要合的提交
- [ ] PR 正文的 `N` 与真实 diff 路径数一致
- [ ] 平台/已测/未测/类型/兼容回滚都有值
- [ ] 反证与未验没有被写成自证
- [ ] required checks 都是最新 head 的成功运行

## Verdict

- 任意 Scope 项失败 → `FAIL`
- Evidence 缺失或不是 PASS → `FAIL`
- 只有未验项 → `NEEDS HUMAN`
- 全部可核对 → `PASS`

复述时引用具体路径、命令、行号；不要只写“看起来没问题”。
