/// `tool/docs` 六条规则的回归。
///
/// 为什么检查器要自测：规则自己改错了会**静默失效** —— 工具跑绿、人以为文档
/// 自洽、实际什么都没查。本笔就撞过两次：`D1` 在转义反引号处截断名字（5 条假红）、
/// `D4` 把合计行重复计入累加（120 而非 60）。这两处都不是用例抓出来的，是「跑出来
/// 的红数看着不对」才发现的 —— 有自测就能当场定位。
///
/// 夹具全部是内存字符串，不读盘：规则签名是 `DocContext -> List<DocIssue>`，
/// 这样能精确构造「只差一处」的文档集，红了也知道红在哪一行。
library;

import '../../tool/docs/rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 一份**自洽**的迷你四件套。每个用例只改其中一处，让红点唯一。
Map<String, String> _docs() => <String, String>{
      scmpFile: '''
> **版号**：`v0.1.0` · **状态**：ok

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建 |

| `v0.1.0` | 1 | `SCMP`（x） |
| `v0.1.0` | 1 | `STD`（x） |
| `v0.1.0` | 1 | `STP`（x） |
| `v0.1.0` | 1 | `STR`（x） |
''',
      stdFile: '''
> **版号**：`v0.1.0` · **状态**：§三 用例表 **2 条** · `flutter test` **2**

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建 |

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-FND-001` | `FND-001` | 显式 | — | — | — | Unit | `app/test/a_test.dart` · `甲` |
| `TC-FND-002` | `FND-001` | 语义 | — | — | — | Unit | 同上 · `乙` |

| 口径 | 数量 |
|---|---|
| `SPEC` 唯一编号总数（实测） | **2** |
| 有对应用例的 `SPEC` | **1** |
| 无用例 | **1** |

| 域 | `SPEC` 总数 | 有用例 | 缺口 |
|---|---|---|---|
| `FND` | 2 | 1 | 1 |
| **合计** | **2** | **1** | **1** |
''',
      stpFile: '''
> **版号**：`v0.1.0` · **状态**：§五 用例 **2** 条

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建 |

| 层 | 用例数 | 编号 | 跑法 |
|---|---|---|---|
| 单元 | 2 | `TC-FND-001`–`002` | `flutter test` |
| **合计** | **2** | — | — |
''',
      strFile: '''
> **版号**：`v0.1.0` · **记录类**：追加

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建。`flutter test` **2 passed** |
''',
    };

Map<String, String> _tests() => <String, String>{
      'app/test/a_test.dart': "test('甲', () {});\ntest('乙', () {});\n",
    };

List<DocIssue> _run(
  Map<String, String> docs, {
  Map<String, String>? tests,
  Map<String, String> markdown = const <String, String>{},
  Set<String> repoPaths = const <String>{},
}) => checkAll(
      DocContext(
        docs: docs,
        tests: tests ?? _tests(),
        markdown: markdown,
        repoPaths: repoPaths,
      ),
    );

/// `D6` 的夹具：一份位于 `docs/a/note.md` 的文档，与它「周围真实存在」的路径集。
///
/// 路径集刻意包含**目录**（`docs/reference`）：链接指向目录是合法写法，只收文件
/// 会把这类判成坏链 —— 这条约定由 `TC-DOC-016` 守住。
Set<String> _repoPaths() => <String>{
      'docs',
      'docs/a',
      'docs/a/note.md',
      'docs/a/target.md',
      'docs/reference',
      'docs/reference/path-rules.md',
    };

List<DocIssue> _runLinks(String body) => _run(
      _docs(),
      markdown: <String, String>{'docs/a/note.md': body},
      repoPaths: _repoPaths(),
    );

/// 把某份文档里的一段替换掉。夹具用，`old` 必须唯一存在。
Map<String, String> _patch(Map<String, String> docs, String file, String old, String now) {
  final String? src = docs[file];
  expect(src, isNotNull, reason: '夹具里没有 $file');
  expect(src!.contains(old), isTrue, reason: '要替换的片段不存在：$old');
  return <String, String>{...docs, file: src.replaceFirst(old, now)};
}

void main() {
  group('D1 落点列', () {
    test('TC-DOC-001 自洽的四件套应当零违规（无 SPEC：检查器自身的基线，设计规格里尚无对应条目）', () {
      expect(_run(_docs()), isEmpty);
    });

    test('TC-DOC-002 落点写的文件不存在就报（无 SPEC：检查器规则，设计规格里尚无对应条目）', () {
      final Map<String, String> d = _patch(
        _docs(),
        stdFile,
        '`app/test/a_test.dart` · `甲`',
        '`app/test/missing_test.dart` · `甲`',
      );
      final List<DocIssue> issues = _run(d);
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, 'D1');
      expect(issues.single.message, contains('missing_test.dart'));
      final List<String> lines = d[stdFile]!.split('\n');
      final int row = lines.indexWhere((String l) => l.contains('TC-FND-001')) + 1;
      expect(issues.single.line, row, reason: '应指向用例表的第 1 行用例');
    });

    test('TC-DOC-003 落点只写文件名且有两份同名时报二义（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, '`app/test/a_test.dart` · `甲`', '`a_test.dart` · `甲`'),
        tests: <String, String>{
          'app/test/a_test.dart': "test('甲', () {});",
          'app/test/core/a_test.dart': "test('乙', () {});",
        },
      );
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('2 份同名'));
    });

    test('TC-DOC-004 带编号的测试名必须逐字存在，摘要式不校验（无 SPEC：检查器规则）', () {
      // 摘要式的 `甲` 对不上也不报（586 条里大半是这种形态，逐字校验会淹没真问题）。
      expect(_run(_docs()), isEmpty);

      final Map<String, String> d = _patch(
        _docs(),
        stdFile,
        '`app/test/a_test.dart` · `甲`',
        '`app/test/a_test.dart` · `TC-FND-001 甲（无 SPEC：…）`',
      );
      final List<DocIssue> issues = _run(d);
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('TC-FND-001 甲（无 SPEC：…）'));
    });
  });

  group('D2 版号', () {
    test('TC-DOC-005 头部版号取修订历史的语义最大，不依赖行的位置（无 SPEC：检查器规则）', () {
      Map<String, String> d = _patch(
        _docs(),
        stdFile,
        '`v0.1.0` | 2026-10-17 | 首建',
        // 故意**倒序**：最大的排前面、最小的排最后。若实现是「取最后一行」，
        // 会得到 v0.2.0 而误报；只有「取语义最大」才对。顺带证明检查不依赖位置。
        '`v0.3.0` | 2026-10-19 | 又加\n| `v0.2.0` | 2026-10-18 | 加',
      );
      d = _patch(d, stdFile, '> **版号**：`v0.1.0`', '> **版号**：`v0.3.0`');
      d = _patch(d, scmpFile, '| `v0.1.0` | 1 | `STD`（x） |', '| `v0.3.0` | 1 | `STD`（x） |');
      final List<DocIssue> issues = _run(d);
      // 表内乱序但最大值对得上 ⇒ 不报。
      expect(issues.where((DocIssue i) => i.ruleId == 'D2'), isEmpty);
    });

    test('TC-DOC-006 头部与修订历史最大版号不符就报（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          stdFile,
          '> **版号**：`v0.1.0`',
          '> **版号**：`v0.9.0`',
        ),
      );
      final List<DocIssue> d2 =
          issues.where((DocIssue i) => i.ruleId == 'D2').toList();
      expect(d2, hasLength(2), reason: '头部 → 修订历史 1 处，SCMP §5.1 登记 1 处');
      expect(d2.first.message, contains('v0.9.0'));
    });

    test('TC-DOC-007 SCMP §5.1 登记的版号必须等于对方头部（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), scmpFile, '| `v0.1.0` | 1 | `STD`（x） |', '| `v0.0.9` | 1 | `STD`（x） |'),
      );
      final List<DocIssue> d2 =
          issues.where((DocIssue i) => i.ruleId == 'D2').toList();
      expect(d2, hasLength(1));
      expect(d2.single.message, contains('§5.1 登记 STD 为 v0.0.9'));
    });
  });

  group('D3 用例数', () {
    test('TC-DOC-008 STD 头部声明的条数必须等于用例表实扫（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, '§三 用例表 **2 条**', '§三 用例表 **3 条**'),
      );
      final List<DocIssue> d3 =
          issues.where((DocIssue i) => i.ruleId == 'D3').toList();
      expect(d3, hasLength(1), reason: '只有 STD 头部这一处 —— STP 合计仍等于实扫的 2');
      expect(d3.first.message, contains('头部声明 3 条'));
    });

    test('TC-DOC-009 STP 分段编号展开必须等于合计（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stpFile, '| 单元 | 2 | `TC-FND-001`–`002`',
            '| 单元 | 2 | `TC-FND-001`'),
      );
      final List<DocIssue> d3 =
          issues.where((DocIssue i) => i.ruleId == 'D3').toList();
      expect(d3, hasLength(1));
      expect(d3.single.message, contains('分段编号展开 1 条，合计行 2 条'));
      expect(d3.single.message, contains('TC-FND-002'));
    });
  });

  group('D4 SPEC 覆盖', () {
    test('TC-DOC-010 有用例数必须等于用例表里出现过的 SPEC 去重数（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, '| 有对应用例的 `SPEC` | **1** |', '| 有对应用例的 `SPEC` | **2** |'),
      );
      final List<DocIssue> d4 =
          issues.where((DocIssue i) => i.ruleId == 'D4').toList();
      expect(d4, isNotEmpty);
      expect(d4.first.message, contains('称有对应用例的 `SPEC` 为 2 条，用例表实扫 1 条'));
    });

    test('TC-DOC-011 按域表每一行的有用例数也要对得上（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, '| `FND` | 2 | 1 | 1 |', '| `FND` | 2 | 2 | 0 |'),
      );
      final List<DocIssue> d4 =
          issues.where((DocIssue i) => i.ruleId == 'D4').toList();
      expect(d4.map((DocIssue i) => i.message).join('\n'), contains('按域表 `FND` 写有用例 2 条'));
    });
  });

  group('D5 头部读数', () {
    test('TC-DOC-012 头部 flutter test 读数落后于 STR 最新轮次就报（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, '`flutter test` **2**', '`flutter test` **1**'),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1));
      expect(d5.single.message, contains('头部写 `flutter test` 1 条'));
      expect(d5.single.message, contains('实跑 2 条'));
    });

    test('TC-DOC-013 权威轮次取语义最大版号，不取最后一行（无 SPEC：检查器规则）', () {
      // 新轮次排在**前面**、旧轮次排在**后面**，且两者读数不同（4 / 2）。
      // 头部写 2 —— 若实现是「取最后一行」，会拿到 2 而误判为一致（零红）；
      // 只有「取语义最大」才会拿到 `v0.3.0` 的 4 并报出来。
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          strFile,
          '| `v0.1.0` | 2026-10-17 | 首建。`flutter test` **2 passed** |',
          '| `v0.3.0` | 2026-10-19 | 又一轮。`flutter test` **4 passed** |\n'
              '| `v0.1.0` | 2026-10-17 | 首建。`flutter test` **2 passed** |',
        ),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1), reason: '取最后一行会得 2，与头部一致 ⇒ 零红，就验不出这条');
      expect(d5.single.message, contains('v0.3.0'));
      expect(d5.single.message, contains('实跑 4 条'));
    });

    test('TC-DOC-014 最新轮次没登记读数只警告，不阻断（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), strFile, '首建。`flutter test` **2 passed**', '首建。'),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1));
      expect(d5.single.isWarning, isTrue, reason: '读数缺失是信息损失，不是两个数打架');
      expect(d5.single.message, contains('无从核对'));
    });

    test('TC-DOC-015 头部没写读数只警告，不去猜（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, ' · `flutter test` **2**', ''),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1));
      expect(d5.single.isWarning, isTrue);
      expect(d5.single.message, contains('唯一登记处'));
    });
  });

  group('D6 相对链接', () {
    test('TC-DOC-016 指向存在的文件或目录都不报（无 SPEC：检查器规则）', () {
      // 同目录目标、上跳到另一个目录、以及**指向目录**（`../reference/` → `docs/reference`，
      // 路径集里有这个目录但没有「同名文件」）三种合法形态。
      final List<DocIssue> issues = _runLinks(
        '见 [同目录](target.md)、[目录](../reference/)、'
        '[带锚点](target.md#三) 与 [本文档](#一)。\n',
      );
      expect(issues, isEmpty);
    });

    test('TC-DOC-017 指向不存在的文件就报，并把解析后的路径写进消息（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _runLinks('见 [坏](missing.md)。\n');
      expect(issues, hasLength(1));
      expect(issues.single.ruleId, 'D6');
      expect(issues.single.line, 1);
      expect(issues.single.message, contains('missing.md'));
      expect(issues.single.message, contains('docs/a/missing.md'),
          reason: '只报原文不够 —— 得说清它被解析成了什么，才能判断是写错还是判断错');
    });

    test('TC-DOC-018 少一层上跳会解析到错误目录（本仓真实踩过的形态，无 SPEC：检查器规则）', () {
      // 真实事故：`docs/deliverables/01-plan/` 下写 `../design/00-index.md`，
      // 以为是 `docs/design/`，实际解析成 `docs/deliverables/design/`。
      // 这里用同样的错法复现：从 `docs/a/note.md` 写 `../target.md`。
      final List<DocIssue> issues = _runLinks('见 [坏](../target.md)。\n');
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('解析为 `docs/target.md`'),
          reason: '若实现少退一层（当成 `docs/a/target.md`）本例不报，就验不出这条');
    });

    test('TC-DOC-019 上跳越过仓库根单独报，不与「文件不存在」混为一谈（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _runLinks('见 [坏](../../../outside.md)。\n');
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('越过仓库根'));
    });

    test('TC-DOC-020 外链 / 锚点 / 站内绝对路径 / 围栏内 / 行内代码里的链接一律不校验（无 SPEC：检查器规则）', () {
      // 五类都放**坏**目标：只要实现漏掉任何一类过滤，这里就会红。
      final List<DocIssue> issues = _runLinks(
        '[外链](https://example.com/none.md) · [邮件](mailto:a@b.c) · '
        '[锚点](#三) · [站内绝对](/docs/none.md)\n'
        '\n'
        '```dart\n'
        '[示例](nowhere.md)\n'
        '```\n'
        '\n'
        '正文里描述链接语法时要写 `[参考层](reference/)` 这种形态，它不是真链接。\n'
        // 多反引号定界：描述「链接文本里带反引号」时就是这个写法。单反引号的正则
        // 会剥成半截、剩下 `](y)` 被当真链接 —— 实跑在 `STR` 里踩过一次。
        '带反引号的链接文本写成 `` [`x`](y) `` 才对。\n',
      );
      expect(issues, isEmpty, reason: '围栏与行内代码里贴示例是常态，校验它只会制造假红');
    });
  });
}
