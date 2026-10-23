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
///
/// ⚠️ 形态跟着 `S7-2` 走：仓内参与版号自洽的四份（`SCMP` / `STD` / `STP` / `SDD`）
/// **一律没有头部版号**，版号只在末尾「历史（迁移前版号序列）」节里；`STR` 已出仓，
/// 夹具里不再有它 —— `S7-2` 之前那份「头部版号 + 修订历史」的老形态夹具随分支一起删了
/// （两种形态的对照只在 `S7-1`→`S7-2` 之间成立，现在只有一种形态，留个空壳夹具
/// 会让人以为还有另一条分支要测）。
///
/// `STD` 末尾带 `## 六、当前读数` —— `D5` 的锚点。**每份夹具都必须带**，否则
/// `TC-DOC-004` 那种「整体零报」的断言会先被「找不到当前读数节」的警告顶掉。
Map<String, String> _docs() => <String, String>{
      scmpFile: '''
> **状态**：ok

| `v0.1.0` | 1 | `SCMP`（x） |
| `v0.1.0` | 1 | `STD`（x） |
| `v0.1.0` | 1 | `STP`（x） |
| `v0.1.0` | 1 | `SDD`（x） |

## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建 |
''',
      stdFile: '''
> **状态**：§三 用例表 **2 条**

## 历史（迁移前版号序列）

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

## 六、当前读数

| 读数 | 当前值 | 采集方式 |
|---|---|---|
| `flutter test` | **2 passed** | 在 `app/` 下整跑 |
''',
      stpFile: '''
> **状态**：§五 用例 **2** 条

## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建 |

| 层 | 用例数 | 编号 | 跑法 |
|---|---|---|---|
| 单元 | 2 | `TC-FND-001`–`002` | `flutter test` |
| **合计** | **2** | — | — |
''',
      // `SDD` 只参与版号自洽（`versionDocFiles`）。夹具必须给，否则 `D2` 会对它报
      // 「文件不存在」—— 那正是「覆盖了却没读盘」的形态，与本条要抓的错是同一类。
      sddFile: '''
> **状态**：ok

## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.1.0` | 2026-10-17 | 首建 |
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
    test('TC-DOC-001 自洽的五件套应当零违规（无 SPEC：检查器自身的基线，设计规格里尚无对应条目）', () {
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
    test('TC-DOC-005 历史节取语义最大版号，不依赖行的位置（无 SPEC：检查器规则）', () {
      Map<String, String> d = _patch(
        _docs(),
        sddFile,
        '| `v0.1.0` | 2026-10-17 | 首建 |',
        // 故意**倒序**：最大的排前面、最小的排最后。若实现是「取最后一行」，
        // 会得到 v0.1.0 而误报；只有「取语义最大」才对。顺带证明检查不依赖位置。
        // ⚠️ 2026-10-23 起「降序」本身成了硬判据（`TC-DOC-021` 守倒挂），所以这个
        // 夹具同时是**合法形态** —— 本条守「取值不看位置」，与那条守「位置必须对」
        // 是两条正交的判据，别把它们混成一条。
        '| `v0.3.0` | 2026-10-19 | 又加 |\n'
            '| `v0.1.0` | 2026-10-17 | 首建 |',
      );
      d = _patch(
          d, scmpFile, '| `v0.1.0` | 1 | `SDD`（x） |', '| `v0.3.0` | 1 | `SDD`（x） |');
      final List<DocIssue> issues = _run(d);
      // 表内乱序但最大值对得上 ⇒ 不报。
      expect(issues.where((DocIssue i) => i.ruleId == 'D2'), isEmpty);
    });

    test('TC-DOC-006 历史节最大版号与 §5.1 登记不符就报，SDD 仍在检查范围内（无 SPEC：检查器规则）', () {
      // 夹具刻意用 `SDD`：它是四份里最不常被翻的一份。若实现漏掉 `SDD`，
      // 这条会零红 —— 而原实现（只有四份）正是笔 4 那次 `SDD` 头部停在
      // `v0.13.0`、树里缺八份新文件却没人报的原因。用「被漏掉的那一份」当夹具，
      // 这条才验得出覆盖面。
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          sddFile,
          '| `v0.1.0` | 2026-10-17 | 首建 |',
          '| `v0.9.0` | 2026-10-21 | 后加 |',
        ),
      );
      final List<DocIssue> d2 =
          issues.where((DocIssue i) => i.ruleId == 'D2').toList();
      expect(d2, hasLength(1), reason: '只有 §5.1 那一处');
      expect(d2.single.file, scmpFile, reason: '红点应落在 SCMP §5.1 的登记行上');
      expect(d2.single.isWarning, isFalse,
          reason: '`S7-1` 的过渡降级已在 `S7-2` 撤销 —— 这一支回到 error');
      expect(d2.single.message, contains('v0.9.0'));
    });

    test('TC-DOC-007 SCMP §5.1 登记的版号必须等于对方历史节最大版号（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(_docs(), scmpFile, '| `v0.1.0` | 1 | `STD`（x） |', '| `v0.0.9` | 1 | `STD`（x） |'),
      );
      final List<DocIssue> d2 =
          issues.where((DocIssue i) => i.ruleId == 'D2').toList();
      expect(d2, hasLength(1));
      expect(d2.single.isWarning, isFalse, reason: '`S7-2` 起是 error，不是警告');
      expect(d2.single.message, contains('§5.1 登记 STD 为 v0.0.9'));
    });

    test('TC-DOC-021 历史表必须按版号降序，倒挂就报（无 SPEC：检查器规则）', () {
      // 升序 = `v0.1.0` 在前、`v0.3.0` 在后 —— 正是 2026-10-23 之前六份表的形态。
      Map<String, String> d = _patch(
        _docs(),
        sddFile,
        '| `v0.1.0` | 2026-10-17 | 首建 |',
        '| `v0.1.0` | 2026-10-17 | 首建 |\n'
            '| `v0.3.0` | 2026-10-19 | 又加 |',
      );
      // §5.1 同步登记 `v0.3.0`，否则「版号对不上」会再加一处，断言就不唯一了。
      d = _patch(
          d, scmpFile, '| `v0.1.0` | 1 | `SDD`（x） |', '| `v0.3.0` | 1 | `SDD`（x） |');
      final List<DocIssue> issues = _run(d);
      final List<DocIssue> d2 =
          issues.where((DocIssue i) => i.ruleId == 'D2').toList();
      expect(d2, hasLength(1), reason: '版号本身对得上，只有降序一处');
      expect(d2.single.message, contains('应排在 v0.1.0 之前'));
      expect(d2.single.line, greaterThan(0), reason: '行号要指到倒挂的那一行');
    });

    test('TC-DOC-022 历史表同版号出现两次也报（无 SPEC：检查器规则）', () {
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          sddFile,
          '| `v0.1.0` | 2026-10-17 | 首建 |',
          '| `v0.1.0` | 2026-10-17 | 首建 |\n'
              '| `v0.1.0` | 2026-10-19 | 又记一次 |',
        ),
      );
      final List<DocIssue> d2 =
          issues.where((DocIssue i) => i.ruleId == 'D2').toList();
      expect(d2, hasLength(1));
      expect(d2.single.message, contains('应排在 v0.1.0 之前'),
          reason: '相等也报 —— 同版号两行等于同一版本记了两次');
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

  group('D5 读数单点', () {
    test('TC-DOC-012 头部再写 flutter test 读数就报重复登记（无 SPEC：检查器规则）', () {
      // 夹具的 `STD` 头部本来不带读数（正确形态），这里注射一个 —— 它现在是
      // 明确的错：读数的唯一登记处是同一份文件里的 §六「当前读数」节，
      // **在节外任何位置**写都算重复登记，头部只是最容易写错的那一处。
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          stdFile,
          '§三 用例表 **2 条**',
          '§三 用例表 **2 条** · `flutter test` **2**',
        ),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1));
      expect(d5.single.isWarning, isFalse, reason: '节外登记是 error，不是提醒');
      expect(d5.single.message, contains('全仓唯一登记处'));
      expect(d5.single.message, contains('**2**'));
    });

    test('TC-DOC-013 找不到当前读数节就警告，并说清为什么这一节不能缺（无 SPEC：检查器规则）', () {
      // 把节名改掉 —— 节还在、内容还在，但**锚点没了**。这是 `S7-1` 剥版号时
      // 「读头部那一行」失效的同一种故障：判据在，找不到落点，于是整条规则静默。
      // 本版宁可报 warning 说「找不到节」，也不许它静默通过。
      final List<DocIssue> issues = _run(
        _patch(_docs(), stdFile, '## 六、当前读数', '## 六、其它'),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1));
      expect(d5.single.isWarning, isTrue, reason: '节缺失是信息损失，不是两个数打架');
      expect(d5.single.message, contains('找不到「## 当前读数」节'));
    });

    test('TC-DOC-014 当前读数节空着也只警告，不阻断（无 SPEC：检查器规则）', () {
      // **空节比没有节更坏**：它让人以为登记过。所以这一条与 `013` 分开验 ——
      // 两种故障的措辞必须不同，否则读到警告的人不知道该去补节还是补数。
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          stdFile,
          '| `flutter test` | **2 passed** | 在 `app/` 下整跑 |',
          '| `flutter test` | 待跑 | — |',
        ),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, hasLength(1));
      expect(d5.single.isWarning, isTrue, reason: '读数缺失是信息损失，不是两个数打架');
      expect(d5.single.message, contains('「当前读数」节里没有 `flutter test` 读数'));
    });

    test('TC-DOC-015 箭头形态的变化叙述不判成读数（无 SPEC：检查器规则）', () {
      // 「748 → 414」是历史叙述，不是当前读数声明。它不含闭合的 `**N**`，
      // 所以天然不命中 —— 但这条必须有用例钉住：一旦有人把正则放宽成「`flutter test`
      // 后面第一个数字」，每一份修订摘要都会变红灯，而误报比漏报更快毁掉规则。
      final List<DocIssue> issues = _run(
        _patch(
          _docs(),
          stdFile,
          '§三 用例表 **2 条**',
          '§三 用例表 **2 条**（本笔 `flutter test` **4 → 2**）',
        ),
      );
      final List<DocIssue> d5 =
          issues.where((DocIssue i) => i.ruleId == 'D5').toList();
      expect(d5, isEmpty, reason: '箭头形态不是读数声明，不应报');
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

  group('D7 头部状态行', () {
    test('TC-DOC-023 头部出现「上一版」就报，提示指向文末历史表（无 SPEC：检查器规则）', () {
      final Map<String, String> docs = _patch(
        _docs(),
        stdFile,
        '> **状态**：§三 用例表 **2 条**',
        '> **状态**：§三 用例表 **2 条**\n> **上一版**：§三 用例表 **1 条**',
      );
      final List<DocIssue> got = _run(docs)
          .where((DocIssue i) => i.ruleId == 'D7')
          .toList();
      expect(got, hasLength(1));
      expect(got.single.file, stdFile);
      expect(got.single.line, 2);
      expect(got.single.isWarning, isTrue, reason: '头部臃肿是信息组织问题，不阻断');
      expect(got.single.message, contains('上一版'));
      expect(got.single.message, contains('历史表'));
    });

    test('TC-DOC-024 历史表里的「此前」是叙述，不算堆叠（无 SPEC：检查器规则）', () {
      // 负例守着「只扫第一个 `## ` 之前」—— 实现若改成全文件扫，六份历史表
      // 每一行「此前 N → M」都会误报，这条会当场红。
      final Map<String, String> docs = _patch(
        _docs(),
        stdFile,
        '| `v0.1.0` | 2026-10-17 | 首建 |',
        '| `v0.1.0` | 2026-10-17 | 首建（此前 597 → **608**） |',
      );
      expect(
        _run(docs).where((DocIssue i) => i.ruleId == 'D7'),
        isEmpty,
        reason: '它已经是「同一事实只写一处」之后的那一处，不该被本规则反咬',
      );
    });

    test('TC-DOC-025 头部状态行超过 600 字就报，并说出实测字数（无 SPEC：检查器规则）', () {
      final String long = '> **状态**：${'甲' * (headerStatusMaxChars + 1)}';
      final Map<String, String> docs = _patch(
        _docs(),
        sddFile,
        '> **状态**：ok',
        long,
      );
      final List<DocIssue> got = _run(docs)
          .where((DocIssue i) => i.ruleId == 'D7')
          .toList();
      expect(got, hasLength(1));
      expect(got.single.file, sddFile);
      expect(got.single.line, 1);
      expect(
        got.single.message,
        contains('${long.length} 字'),
        reason: '只报「超了」不够 —— 得给出实测值，才知道要删多少',
      );
    });
  });
}
