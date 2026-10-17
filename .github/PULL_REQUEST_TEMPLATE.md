## 变更摘要

<!-- 一句话说清改了什么、为什么改。不用复述 diff。 -->

## 影响面

- [ ] 客户端 `app/`
- [ ] 服务端 `server/`
- [ ] 内容包 `content/`
- [ ] 基础设施 `infra/`
- [ ] 文档 `docs/`

## 自验证证据

<!-- 跑过的命令与输出。单人维护期以此承担评审职责：仅凭「应该能跑」不开 PR。
     跑不了或沙箱跑不了的项（flutter build 三端 / flutter run / 真机验收）如实写
     「未验 + 原因 + 归谁验」，不得留空。 -->

```
$ flutter analyze
$ flutter test
```

## 交付物增量

<!-- 逐份列出本次触及的 docs/deliverables/**；不涉及某项写「不涉及：<理由>」。
     默认单据 DPMR + STR 不得同时为空。映射见 docs/guides/git-conventions.md §四。 -->

- `DPMR`：
- `STR`：
- 其它：

## 版号变化

<!-- 仅当触及 docs/deliverables/** 时填：逐份写「vX.Y.Z → vA.B.C」与递增理由
     （章节重构 / 新增章节 / 勘误）。纯格式规范化不追加修订历史行。 -->

- 无

## 关联

<!-- 一次提交一笔：批次号 + 里程碑 + issue / ADR / 规格条。
     批次号是计划表的最小排期单位（见 SDP §4.2）；一批拆成多个 PR 时必填，否则无法对账闸门。
     #PR 号合入后由 squash 提交正文回填。 -->

- 批次：
- 里程碑：
- issue / ADR / 规格条：
