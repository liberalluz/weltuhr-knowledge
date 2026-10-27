# verifier

C13 的只读验收工具。它只读取 `.batch/<id>/` 和当前 diff，不写文件、不改分支、不合并。

```bash
python3 -B infra/tool/verify/verify.py --batch C12
python3 -B infra/tool/verify/verify.py --batch C12 --json
```

输出四块：

1. **Claim**：card 的 goal / acceptance；
2. **Scope**：实际 changed paths 与 allowed/forbidden 对账；
3. **Evidence**：`evidence.log` 是否有 `RESULT: PASS`；
4. **Unverified**：从 `pr-body.md` / `evidence.log` 抄出的“未验”，不补写。

结论：

| 条件 | 结论 |
|---|---|
| card/scope hash 失效、scope 越界、evidence 缺失 | `FAIL` |
| 无可核对问题，但仍有未验项 | `NEEDS HUMAN` |
| 全部可核对且无未验 | `PASS` |

`verify.py` 只做机械对账；是否接受未验项，由人看报告后决定。配套 checklist 在 `.agents/checklists/acceptance.md`。

## 测试

```bash
python3 -m unittest discover -s infra/tool/verify/tests
```

测试用临时 `.batch` 夹具，不访问网络。
