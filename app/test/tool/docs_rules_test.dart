/// `tool/docs` 四条规则的回归。
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
> **版号**：`v0.1.0` · **状态**：§三 用例表 **2 条**

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
| `v0.1.0` | 2026-10-17 | 首建 |
''',
    };

Map<String, String> _tests() => <String, String>{
      'app/test/a_test.dart': "test('甲', () {});\ntest('乙', () {});\n",
    };

List<DocIssue> _run(Map<String, String> docs, {Map<String, String>? tests}) =>
    checkAll(DocContext(docs: docs, tests: tests ?? _tests()));

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
}
