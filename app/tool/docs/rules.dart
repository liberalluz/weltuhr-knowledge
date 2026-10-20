/// 交付物一致性检查的六条规则（`D1`–`D6`）。
///
/// 为什么单独一支、不进 `tool/lint`：`lint` 管的是**代码**的架构不变量（`R1`–`R5`），
/// 判据是「这一行代码违反了哪条约束」；这里管的是**四份交付物之间的口径**，判据是
/// 「两个地方写的数是不是同一个」。两者的输入（源码 vs. Markdown + 测试文件）与
/// 失效方式都不同，混在一支里会让 `lint` 的退出码含义变模糊。
///
/// 为什么要有这套东西：升版一笔交付物，同一个读数会散在四处到十一处，且**措辞各异**
/// ——「`Dart` 用例 561 条」「584 → **597** 条」「`v0.47.0` | 1 |」三种形态，批量替换
/// 不可能，只能逐处手写。于是漏改必然发生，且只有人眼能发现。实测两次：`SCMP` 修订
/// 历史漏了 `v0.45.0` 整行、`STD` §4.1 的按域表连续两版没跟。规则就是把这两类漏改
/// 变成机器能报的东西。
///
/// 规则是纯函数：`DocContext -> List<DocIssue>`，不读盘。这样可以直接拿字符串测。
library;

/// 一条口径不一致。
class DocIssue {
  const DocIssue({
    required this.ruleId,
    required this.file,
    required this.line,
    required this.message,
    this.isWarning = false,
  });

  final String ruleId;

  /// 相对仓库根的路径，与 `git status` 里的写法一致，便于直接定位。
  final String file;

  /// 1 起算。跨文件 / 全局性的问题记 `0`。
  final int line;

  final String message;

  /// 警告不阻断。只用在「历史债」上 —— 当下改不了、也不该由本工具强改的东西。
  final bool isWarning;

  @override
  String toString() =>
      '$file:$line [$ruleId]${isWarning ? '（警告）' : ''} $message';
}

/// 一次检查需要的全部输入，一次性读进来。
class DocContext {
  const DocContext({
    required this.docs,
    required this.tests,
    this.markdown = const <String, String>{},
    this.repoPaths = const <String>{},
  });

  /// 相对仓库根的文件路径 → 内容。
  final Map<String, String> docs;

  /// 相对仓库根的测试文件路径 → 内容。键要做成 `app/test/...` 形式，
  /// 与 `STD` 落点列的写法一致。
  final Map<String, String> tests;

  /// 参与 `D6` 链接检查的 **全部** Markdown：相对仓库根路径 → 内容。
  ///
  /// 比 [docs] 宽得多（`docs/` 67 份 + `.github/` 与各目录 README，实测 91 份）
  /// —— 这是刻意的：链接断掉的地方**不限于四份交付物**，`00-index` / `reference/`
  /// 这些引用层文件才是相对链接最密集的地方。
  ///
  /// 缺省为空集，于是 `D6` 对只构造了 [docs] / [tests] 的老用例零影响。
  final Map<String, String> markdown;

  /// 仓库内的**全部**文件与目录（相对仓库根，`/` 分隔），供 `D6` 判目标是否存在。
  ///
  /// 含目录：链接可以指向一个目录（`[参考层](reference/)`），那不算坏链。
  final Set<String> repoPaths;
}

/// 参与口径检查的四份文件。顺序即报错顺序。
///
/// 只有这四份：它们之间**互相登记对方的版号与读数**（`SCMP` §5.1 登三份的版号，
/// `STD` 声明用例数、`STP` 汇总同一个数）。其余交付物单向来引，不构成环，没有
/// 「两处写同一个数」的问题。
const List<String> docFiles = <String>[
  'docs/deliverables/01-plan/SCMP-软件配置管理计划.md',
  'docs/deliverables/04-test/STD-软件测试说明.md',
  'docs/deliverables/04-test/STP-软件测试计划.md',
  'docs/deliverables/04-test/STR-软件测试报告.md',
];

const String scmpFile = 'docs/deliverables/01-plan/SCMP-软件配置管理计划.md';
const String stdFile = 'docs/deliverables/04-test/STD-软件测试说明.md';
const String stpFile = 'docs/deliverables/04-test/STP-软件测试计划.md';
const String strFile = 'docs/deliverables/04-test/STR-软件测试报告.md';

/// 配置项标识 → 文件。`SCMP` §5.1 第三列以此开头。
const Map<String, String> itemIdToFile = <String, String>{
  'SCMP': scmpFile,
  'STD': stdFile,
  'STP': stpFile,
  'STR': strFile,
};

final RegExp _versionRe = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');
final RegExp _headVersionRe = RegExp(r'^> \*\*版号\*\*：`(v\d+\.\d+\.\d+)`');
final RegExp _caseRowRe = RegExp(r'^\|\s*(?:~~)?`TC-[A-Z]+-\d+`');
final RegExp _ticketRe = RegExp(r'`(TC-[A-Z]+-\d+)`');
final RegExp _specRe = RegExp(r'([A-Z]{3,6})-\d{3}');

/// `STD` 头部状态行里的 `flutter test` 读数。
final RegExp _stdTestCountRe = RegExp(r'`flutter test`\s*\*\*(\d+)\*\*');

/// `STR` 轮次读数。两种写法都收：`` `flutter test` **572 passed** `` 与
/// `（**572 passed** · analyze 0）` —— 后者是 `STR` 历史行的实际形态。
final RegExp _passedRe = RegExp(r'\*\*(\d+)\s+passed\*\*');

/// 跑全部规则。
List<DocIssue> checkAll(DocContext ctx) {
  return <DocIssue>[
    ...checkD1TestNames(ctx),
    ...checkD2Versions(ctx),
    ...checkD3CaseCounts(ctx),
    ...checkD4SpecCoverage(ctx),
    ...checkD5TestCount(ctx),
    ...checkD6Links(ctx),
  ];
}

// ---------------------------------------------------------------------------
// D1 · 落点列
// ---------------------------------------------------------------------------

/// `D1`：`STD` 用例表的「落点 / 测试名」列必须能落地。
///
/// 三种 token 分三种处理：
///
/// - **`.dart` 路径**：带 `/` 的按仓库相对路径查；只写文件名的（`fold_test.dart`）
///   在 `test/` 下查 basename，且必须**唯一** —— 两份同名测试文件时无法判断落点。
/// - **带编号的完整测试名**（`TC-PLAN-019 L0 → …（SPEC-PLAN-020）`）：必须在某个
///   `test('…')` 里**逐字**存在。这一类是声明的（编号 + 全名），一漂移就再也找不
///   到对应关系，所以才要逐字校验。实测 `P-3` 就在这上面漂过 5 条：我在 `STD` 里
///   写成 `（无 SPEC：…）` 省略号，与测试文件里的全名不符。
/// - **摘要式描述**（`HLC 全序比较`）：只给人读，不承诺与 `test()` 的字面量相同。
///   **不校验** —— 597 条用例里 586 条是这种形态，逐字校验会报 210 条假红，把
///   真问题淹掉。覆盖面交给 `R5`（测试侧必须标裁定来源）与 `D4`（`SPEC` 覆盖数
///   与用例表对得上）。
List<DocIssue> checkD1TestNames(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  final String? stdText = c.docs[stdFile];
  if (stdText == null) {
    return <DocIssue>[
      const DocIssue(
        ruleId: 'D1',
        file: stdFile,
        line: 0,
        message: '文件不存在，无法检查落点列',
      ),
    ];
  }

  // basename → 完整路径列表，用于解析只写了文件名的落点。
  final Map<String, List<String>> byBase = <String, List<String>>{};
  for (final String path in c.tests.keys) {
    final String base = path.split('/').last;
    byBase.putIfAbsent(base, () => <String>[]).add(path);
  }

  final List<String> lines = stdText.split('\n');
  for (int i = 0; i < lines.length; i++) {
    if (!_caseRowRe.hasMatch(lines[i])) {
      continue;
    }
    final List<String> cells = _splitRow(lines[i]);
    if (cells.length < 2) {
      continue;
    }
    // 落点列里，测试名**自己**含反引号（`（无 SPEC：`PLAN-020` …）`）时只能转义成
    // `\`` —— 直接按 `` `([^`]+)` `` 抽，会在转义处提前截断，抽出来的是半截名字。
    // 先把转义对换成占位符，抽完再还原。
    const String bt = '\u0000BT\u0000';
    final String landing = cells.last.replaceAll(r'\`', bt);
    for (final RegExpMatch m in RegExp(r'`([^`]+)`').allMatches(landing)) {
      final String tok = m.group(1)!.replaceAll(bt, '`');
      if (tok.endsWith('.dart')) {
        if (tok.contains('/')) {
          if (!c.tests.containsKey(tok)) {
            out.add(
              DocIssue(
                ruleId: 'D1',
                file: stdFile,
                line: i + 1,
                message: '落点文件不存在：$tok',
              ),
            );
          }
        } else {
          final List<String> hits = byBase[tok] ?? const <String>[];
          if (hits.isEmpty) {
            out.add(
              DocIssue(
                ruleId: 'D1',
                file: stdFile,
                line: i + 1,
                message: '落点只写了文件名，`test/` 下找不到：$tok',
              ),
            );
          } else if (hits.length > 1) {
            out.add(
              DocIssue(
                ruleId: 'D1',
                file: stdFile,
                line: i + 1,
                message: '落点只写了文件名，`test/` 下有 ${hits.length} 份同名：$tok',
              ),
            );
          }
        }
        continue;
      }
      // 带编号的完整测试名才校验；摘要式跳过。
      if (!RegExp(r'^TC-[A-Z]+-\d+\s+\S').hasMatch(tok)) {
        continue;
      }
      if (!_hasTestName(c.tests, tok)) {
        out.add(
          DocIssue(
            ruleId: 'D1',
            file: stdFile,
            line: i + 1,
            message: '带编号的测试名在 `test/` 里找不到逐字匹配：$tok',
          ),
        );
      }
    }
  }
  return out;
}

bool _hasTestName(Map<String, String> tests, String name) {
  final String single = "test('$name'";
  final String double_ = 'test("$name"';
  for (final String src in tests.values) {
    if (src.contains(single) || src.contains(double_)) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// D2 · 版号
// ---------------------------------------------------------------------------

/// `D2`：四份文件的版号必须自洽。
///
/// 两个方向：
///
/// 1. **各自内部**：头部 `> **版号**：`vX.Y.Z`` 必须是修订历史表里的**最大值**。
///    取最大值而不是「最后一行」—— 四份表的排序方向并不统一（`STD` / `STP` 升序、
///    `SCMP` 前段降序后段升序、`STR` 中间还夹着 `v0.18.0` 在 `v0.17.0` 前面），
///    依赖位置就得先修表；而修表是另一件事，不该挡住这条检查。
/// 2. **`SCMP` §5.1 对三份**：表里 `SCMP` / `STD` / `STP` / `STR` 四行的版号，
///    必须等于对应文件头部的版号。这是**唯一一处**跨文件登记版号的地方，
///    它一旦滞后，读者按 §5.1 找基线就会找错。
List<DocIssue> checkD2Versions(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  final Map<String, String> head = <String, String>{};

  for (final String f in docFiles) {
    final String? text = c.docs[f];
    if (text == null) {
      out.add(DocIssue(ruleId: 'D2', file: f, line: 0, message: '文件不存在'));
      continue;
    }
    final List<String> lines = text.split('\n');

    String? headVer;
    int headLine = 0;
    for (int i = 0; i < lines.length; i++) {
      final RegExpMatch? m = _headVersionRe.firstMatch(lines[i]);
      if (m != null) {
        headVer = m.group(1);
        headLine = i + 1;
        break;
      }
    }
    if (headVer == null) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: 0,
          message: '找不到头部版号行（应为 `> **版号**：`vX.Y.Z``）',
        ),
      );
      continue;
    }
    head[f] = headVer;

    // 修订历史表：表头含「版号」的那张。
    final int start = _findTableStart(lines, (String l) => _splitRow(l).isNotEmpty && _splitRow(l).first == '版号');
    if (start < 0) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: headLine,
          message: '找不到修订历史表（表头首列应为「版号」）',
        ),
      );
      continue;
    }
    String? maxVer;
    int maxLine = 0;
    int rows = 0;
    for (int i = start + 1; i < lines.length; i++) {
      if (!lines[i].trim().startsWith('|')) {
        break;
      }
      final List<String> cells = _splitRow(lines[i]);
      if (cells.isEmpty) {
        continue;
      }
      final RegExpMatch? m = _versionRe.firstMatch(cells.first.replaceAll('`', ''));
      if (m == null) {
        continue;
      }
      rows++;
      final String v = cells.first.replaceAll('`', '');
      if (maxVer == null || _compareVersion(v, maxVer) > 0) {
        maxVer = v;
        maxLine = i + 1;
      }
    }
    if (maxVer == null) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: start + 1,
          message: '修订历史表里没有任何版号行',
        ),
      );
      continue;
    }
    if (maxVer != headVer) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: headLine,
          message: '头部版号 $headVer 与修订历史最大版号 $maxVer 不一致（后者在 $f:$maxLine）',
        ),
      );
    }
    if (rows == 0) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: start + 1,
          message: '修订历史表为空',
        ),
      );
    }
  }

  // SCMP §5.1：`| `vX.Y.Z` | 1 | `SCMP`（…` |
  final String? scmp = c.docs[scmpFile];
  if (scmp != null) {
    final List<String> lines = scmp.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final List<String> cells = _splitRow(lines[i]);
      if (cells.length < 3) {
        continue;
      }
      final String ver = cells[0].replaceAll('`', '');
      if (_versionRe.firstMatch(ver) == null) {
        continue;
      }
      // 第二列必须是纯数字（份数）；修订历史行第二列是日期，靠这个分开。
      if (!RegExp(r'^\d+$').hasMatch(cells[1])) {
        continue;
      }
      final RegExpMatch? idm = RegExp(r'^`([A-Z]+)`').firstMatch(cells[2]);
      if (idm == null) {
        continue;
      }
      final String id = idm.group(1)!;
      final String? target = itemIdToFile[id];
      if (target == null) {
        continue;
      }
      final String? actual = head[target];
      if (actual != null && actual != ver) {
        out.add(
          DocIssue(
            ruleId: 'D2',
            file: scmpFile,
            line: i + 1,
            message: '§5.1 登记 $id 为 $ver，而 ${target.split('/').last} 头部是 $actual',
          ),
        );
      }
    }
  }

  return out;
}

int _compareVersion(String a, String b) {
  final List<int> pa = _parseVersion(a);
  final List<int> pb = _parseVersion(b);
  for (int i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) {
      return pa[i].compareTo(pb[i]);
    }
  }
  return 0;
}

List<int> _parseVersion(String v) {
  final RegExpMatch? m = _versionRe.firstMatch(v);
  if (m == null) {
    return <int>[0, 0, 0];
  }
  return <int>[
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  ];
}

/// 找表头满足 [predicate] 的那张表的起始行（0 起算），找不到返回 `-1`。
int _findTableStart(List<String> lines, bool Function(String) predicate) {
  for (int i = 0; i < lines.length; i++) {
    if (predicate(lines[i])) {
      return i;
    }
  }
  return -1;
}

// ---------------------------------------------------------------------------
// D3 · 用例数
// ---------------------------------------------------------------------------

/// `D3`：用例数三个口径必须是同一个数。
///
/// - `STD` 用例表的行数（首列是 `TC-XXX-NNN`，含已作废的那些 —— 作废仍是
///   「写过的用例」，加删除线只是标状态，不是删行）。
/// - `STD` 头部状态行声明的条数。
/// - `STP` §5.1 合计行。
///
/// 外加 **`STP` 分段与合计自洽**：汇总表逐行的编号列展开成边号集合，总数必须
/// 等于合计行。这一条比前三条更细 —— 前三者可以一起写错（抄同一个数），分段表
/// 却要**逐段列对编号**，抄不出来。
List<DocIssue> checkD3CaseCounts(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];

  final String? std = c.docs[stdFile];
  if (std == null) {
    return <DocIssue>[
      const DocIssue(ruleId: 'D3', file: stdFile, line: 0, message: '文件不存在'),
    ];
  }
  final List<String> stdLines = std.split('\n');
  final Set<String> ids = <String>{};
  int rows = 0;
  for (final String l in stdLines) {
    if (!_caseRowRe.hasMatch(l)) {
      continue;
    }
    rows++;
    final RegExpMatch? m = _ticketRe.firstMatch(l);
    if (m != null) {
      ids.add(m.group(1)!);
    }
  }
  final int declared = ids.length;

  final RegExpMatch? headM =
      RegExp(r'§三 用例表 \*\*(\d+) 条\*\*').firstMatch(std);
  if (headM == null) {
    out.add(
      const DocIssue(
        ruleId: 'D3',
        file: stdFile,
        line: 3,
        message: '头部状态行里找不到「§三 用例表 **N 条**」',
      ),
    );
  } else {
    final int claimed = int.parse(headM.group(1)!);
    if (claimed != declared) {
      out.add(
        DocIssue(
          ruleId: 'D3',
          file: stdFile,
          line: 3,
          message: '头部声明 $claimed 条，用例表实扫 ${ids.length} 个边号（$rows 行）',
        ),
      );
    }
  }

  final String? stp = c.docs[stpFile];
  if (stp == null) {
    out.add(
      const DocIssue(ruleId: 'D3', file: stpFile, line: 0, message: '文件不存在'),
    );
    return out;
  }
  final List<String> stpLines = stp.split('\n');

  // 合计行
  int? total;
  int totalLine = 0;
  for (int i = 0; i < stpLines.length; i++) {
    final List<String> cells = _splitRow(stpLines[i]);
    if (cells.length >= 2 && cells.first == '**合计**') {
      final RegExpMatch? m = RegExp(r'^\*{0,2}(\d+)\*{0,2}$').firstMatch(cells[1]);
      if (m != null) {
        total = int.parse(m.group(1)!);
        totalLine = i + 1;
        break;
      }
    }
  }
  if (total == null) {
    out.add(
      const DocIssue(
        ruleId: 'D3',
        file: stpFile,
        line: 0,
        message: '§5.1 找不到 `| **合计** | **N** |` 行',
      ),
    );
    return out;
  }
  if (total != declared) {
    out.add(
      DocIssue(
        ruleId: 'D3',
        file: stpFile,
        line: totalLine,
        message: '§5.1 合计 $total 条，与 `STD` 用例表实扫的 $declared 个边号不一致',
      ),
    );
  }

  // 分段展开
  int tableStart = -1;
  for (int i = 0; i < stpLines.length; i++) {
    if (stpLines[i].contains('| 层 | 用例数 |')) {
      tableStart = i;
      break;
    }
  }
  if (tableStart < 0) {
    out.add(
      const DocIssue(
        ruleId: 'D3',
        file: stpFile,
        line: 0,
        message: '找不到 §5.1 汇总表（表头应为 `| 层 | 用例数 | 编号 | 跑法 |`）',
      ),
    );
    return out;
  }

  final Set<String> claimedIds = <String>{};
  for (int i = tableStart + 2; i < stpLines.length; i++) {
    if (!stpLines[i].trim().startsWith('|')) {
      break;
    }
    final List<String> cells = _splitRow(stpLines[i]);
    if (cells.length < 3) {
      continue;
    }
    claimedIds.addAll(_expandRanges(cells[2]));
  }
  if (claimedIds.length != total) {
    final Set<String> missing = ids.difference(claimedIds);
    final Set<String> extra = claimedIds.difference(ids);
    final String detail = <String>[
      if (missing.isNotEmpty) '`STD` 有而本表未登记 ${_shortList(missing)}',
      if (extra.isNotEmpty) '本表有而 `STD` 没有 ${_shortList(extra)}',
    ].join('；');
    out.add(
      DocIssue(
        ruleId: 'D3',
        file: stpFile,
        line: tableStart + 1,
        message: '§5.1 分段编号展开 ${claimedIds.length} 条，合计行 $total 条'
            '${detail.isEmpty ? '' : '（$detail）'}',
      ),
    );
  }

  return out;
}

/// 把编号列展开成边号集合。
///
/// 列的写法：`` `TC-FND-001`–`006` · `TC-PACK-001`–`002` · `TC-QUANT-001`–`009` ``。
/// 注意区间尾只写数字、不重复前缀。也有整段用一个区间的（`` `TC-VIEW-001`–`040` ``）。
Set<String> _expandRanges(String cell) {
  final Set<String> out = <String>{};
  for (final RegExpMatch seg in RegExp(r'`(TC-[A-Z]+)-(\d+)`(?:–`(\d+)`)?').allMatches(cell)) {
    final String prefix = seg.group(1)!;
    final int from = int.parse(seg.group(2)!);
    final String? toRaw = seg.group(3);
    final int to = toRaw == null ? from : int.parse(toRaw);
    for (int n = from; n <= to; n++) {
      out.add('$prefix-${n.toString().padLeft(3, '0')}');
    }
  }
  return out;
}

String _shortList(Set<String> ids) {
  final List<String> sorted = ids.toList()..sort();
  if (sorted.length <= 6) {
    return sorted.join(' ');
  }
  return '${sorted.take(6).join(' ')} …等 ${sorted.length} 条';
}

// ---------------------------------------------------------------------------
// D4 · SPEC 覆盖数
// ---------------------------------------------------------------------------

/// `D4`：`STD` §4.1 的覆盖统计必须与它自己的用例表对得上。
///
/// 逐项比三处：
///
/// 1. 「有对应用例的 `SPEC`」的总数 vs. 用例表 `SPEC` 列的**去重值域**。
/// 2. 按域表每一行的「有用例」数 vs. 该域在用例表里出现的去重数。
/// 3. 「无用例」= 总数 − 有用例，且按域表各列加总与合计行一致。
///
/// 这一条是 `v0.42.0` / `v0.43.0` 两次漏改的直接产物：那两次只改了正文总数，
/// 按域表一直写着旧数，**同一页里自相矛盾**。自相矛盾比数字过时更糟 ——
/// 读者不知道信哪一行。
List<DocIssue> checkD4SpecCoverage(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  final String? std = c.docs[stdFile];
  if (std == null) {
    return <DocIssue>[
      const DocIssue(ruleId: 'D4', file: stdFile, line: 0, message: '文件不存在'),
    ];
  }
  final List<String> lines = std.split('\n');

  // 用例表实扫：第 2 列（SPEC 列）里的编号，去重。
  final Set<String> covered = <String>{};
  for (final String l in lines) {
    if (!_caseRowRe.hasMatch(l)) {
      continue;
    }
    final List<String> cells = _splitRow(l);
    if (cells.length < 2) {
      continue;
    }
    for (final RegExpMatch m in _specRe.allMatches(cells[1])) {
      covered.add('${m.group(1)}-${m.group(0)!.split('-').last}');
    }
  }

  // §4.1 总量表
  int? claimedCovered;
  int? claimedMissing;
  int? claimedTotal;
  int coveredLine = 0;
  for (int i = 0; i < lines.length; i++) {
    final List<String> cells = _splitRow(lines[i]);
    if (cells.isEmpty) {
      continue;
    }
    final String k = cells.first.replaceAll('`', '');
    final RegExpMatch? num = cells.length >= 2
        ? RegExp(r'^\*{0,2}(\d+)\*{0,2}').firstMatch(cells[1])
        : null;
    if (num == null) {
      continue;
    }
    if (k == '有对应用例的 SPEC' && claimedCovered == null) {
      claimedCovered = int.parse(num.group(1)!);
      coveredLine = i + 1;
    } else if (k == '无用例' && claimedMissing == null) {
      claimedMissing = int.parse(num.group(1)!);
    } else if (k.startsWith('SPEC 唯一编号总数') && claimedTotal == null) {
      claimedTotal = int.parse(num.group(1)!);
    }
  }

  if (claimedCovered == null) {
    out.add(
      const DocIssue(
        ruleId: 'D4',
        file: stdFile,
        line: 0,
        message: '§4.1 找不到「有对应用例的 `SPEC`」行',
      ),
    );
    return out;
  }
  if (claimedCovered != covered.length) {
    out.add(
      DocIssue(
        ruleId: 'D4',
        file: stdFile,
        line: coveredLine,
        message: '§4.1 称有对应用例的 `SPEC` 为 $claimedCovered 条，用例表实扫 '
            '${covered.length} 条'
            '${_delta(covered, claimedCovered)}',
      ),
    );
  }

  // 按域表
  final int domStart = _findTableStart(
    lines,
    (String l) {
      final List<String> cells = _splitRow(l);
      return cells.length >= 4 && cells.first == '域' && cells[1].contains('SPEC');
    },
  );
  if (domStart < 0) {
    out.add(
      const DocIssue(
        ruleId: 'D4',
        file: stdFile,
        line: 0,
        message: '§4.1 找不到按域表（表头首列应为「域」）',
      ),
    );
    return out;
  }

  int sumTotal = 0;
  int sumCovered = 0;
  for (int i = domStart + 2; i < lines.length; i++) {
    if (!lines[i].trim().startsWith('|')) {
      break;
    }
    final List<String> cells = _splitRow(lines[i]);
    if (cells.length < 4) {
      continue;
    }
    final String dom = cells[0].replaceAll('`', '').replaceAll('*', '');
    final RegExpMatch? c = RegExp(r'^\*{0,2}(\d+)\*{0,2}').firstMatch(cells[2]);
    if (c == null) {
      continue;
    }
    final int claimed = int.parse(c.group(1)!);
    final int actual = covered.where((String s) => s.startsWith('$dom-')).length;
    // 合计行只作交叉核对，不能进累加 —— 否则各域之和 + 合计正好翻倍。
    if (dom == '合计') {
      continue;
    }
    sumCovered += claimed;
    if (claimed != actual) {
      out.add(
        DocIssue(
          ruleId: 'D4',
          file: stdFile,
          line: i + 1,
          message: '按域表 `$dom` 写有用例 $claimed 条，用例表实扫 $actual 条',
        ),
      );
    }
    final RegExpMatch? t = RegExp(r'^\*{0,2}(\d+)\*{0,2}').firstMatch(cells[1]);
    if (t != null) {
      sumTotal += int.parse(t.group(1)!);
    }
  }
  if (sumCovered != claimedCovered) {
    out.add(
      DocIssue(
        ruleId: 'D4',
        file: stdFile,
        line: domStart + 1,
        message: '§4.1 按域表「有用例」各列加总 $sumCovered，与总量行的 '
            '$claimedCovered 不一致',
      ),
    );
  }

  // 各域「`SPEC` 总数」加总也要等于总量行。与上面「有用例」那一半合起来，
  // 按域表才算双向对账：只校验一列的话，「有用例 + 缺口 = 总数」这条行内算式
  // 仍然可以三处一起错。
  if (claimedTotal != null && sumTotal != claimedTotal) {
    out.add(
      DocIssue(
        ruleId: 'D4',
        file: stdFile,
        line: domStart + 1,
        message: '§4.1 按域表「`SPEC` 总数」各列加总 $sumTotal，与总量行的 '
            '$claimedTotal 不一致',
      ),
    );
  }

  if (claimedMissing != null && claimedTotal != null) {
    final int expect = claimedTotal - claimedCovered;
    if (claimedMissing != expect) {
      out.add(
        DocIssue(
          ruleId: 'D4',
          file: stdFile,
          line: 0,
          message: '§4.1 无用例写 $claimedMissing，而 总数 $claimedTotal − 有用例 '
              '$claimedCovered = $expect',
        ),
      );
    }
  }

  return out;
}

// ---------------------------------------------------------------------------
// D5 · STD 头部读数
// ---------------------------------------------------------------------------

/// `D5`：`STD` 头部声明的 `flutter test` 读数必须等于**最新一轮实跑**。
///
/// 为什么不归 `D3`：`D3` 对的是「用例表有多少行」，那个数**在文档内部可复算**；
/// `flutter test` 是**执行读数**，四份文档里唯一提供它的是 `STR` 的轮次记录。
/// 两个口径本来就不同（608 行用例 ≠ 572 条 Dart 测试），不能互相校验，只能各找
/// 各的权威源 —— 硬拉在一起只会让两条规则一起说谎。
///
/// 这条规则是补前四条漏掉的那一类：**头部读数不跟正文**。实测连续两版漏改
/// （`v0.44.0` 的 561、`v0.45.0` 的 572 都没写进去，头部一直停在 `v0.43.0` 的
/// 548），而 `D1`–`D4` 一条都不管头部。修的时候刻意**删掉**头部另一处重复的
/// 读数（`SPEC` 覆盖数只在 §4.1 写一份）：能不复制就不需要对账。
///
/// 权威源取 `STR` 修订历史里**语义最大版号**那一行，不取最后一行 —— 与 `D2`
/// 同一个理由：`STR` 的历史当下是乱序的（`v0.18.0` 排在 `v0.2.0` 之后），依赖
/// 位置就得先修表，而修表是另一件事。
List<DocIssue> checkD5TestCount(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  final String? stdText = c.docs[stdFile];
  if (stdText == null) {
    return const <DocIssue>[
      DocIssue(ruleId: 'D5', file: stdFile, line: 0, message: '文件不存在'),
    ];
  }

  final List<String> stdLines = stdText.split('\n');
  int headLine = 0;
  String? claimed;
  for (int i = 0; i < stdLines.length; i++) {
    if (_headVersionRe.firstMatch(stdLines[i]) == null) {
      continue;
    }
    headLine = i + 1;
    claimed = _stdTestCountRe.firstMatch(stdLines[i])?.group(1);
    break;
  }
  if (headLine == 0) {
    return const <DocIssue>[
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: 0,
        message: '找不到头部版号行，无从核对 `flutter test` 读数',
      ),
    ];
  }
  if (claimed == null) {
    out.add(
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: headLine,
        message: '头部未声明 `flutter test` 读数 —— 这是「本版实跑多少条」的唯一登记处，'
            '删掉就再也对不上 `STR`',
        isWarning: true,
      ),
    );
    return out;
  }

  final String? strText = c.docs[strFile];
  if (strText == null) {
    return <DocIssue>[
      ...out,
      const DocIssue(ruleId: 'D5', file: strFile, line: 0, message: '文件不存在'),
    ];
  }
  final List<String> strLines = strText.split('\n');
  final int start = _findTableStart(
    strLines,
    (String l) => _splitRow(l).isNotEmpty && _splitRow(l).first == '版号',
  );
  if (start < 0) {
    return <DocIssue>[
      ...out,
      const DocIssue(
        ruleId: 'D5',
        file: strFile,
        line: 0,
        message: '找不到修订历史表，无从取值',
      ),
    ];
  }

  String? maxVer;
  int maxLine = 0;
  String? maxRow;
  for (int i = start + 1; i < strLines.length; i++) {
    if (!strLines[i].trim().startsWith('|')) {
      break;
    }
    final List<String> cells = _splitRow(strLines[i]);
    if (cells.isEmpty) {
      continue;
    }
    final String v = cells.first.replaceAll('`', '');
    if (_versionRe.firstMatch(v) == null) {
      continue;
    }
    if (maxVer == null || _compareVersion(v, maxVer) > 0) {
      maxVer = v;
      maxLine = i + 1;
      maxRow = strLines[i];
    }
  }
  if (maxVer == null) {
    return <DocIssue>[
      ...out,
      DocIssue(
        ruleId: 'D5',
        file: strFile,
        line: start + 1,
        message: '修订历史表里没有任何版号行',
      ),
    ];
  }

  final String? actual = _passedRe.firstMatch(maxRow!)?.group(1);
  if (actual == null) {
    out.add(
      DocIssue(
        ruleId: 'D5',
        file: strFile,
        line: maxLine,
        message: '`STR` 最新轮次（$maxVer）未登记 `… passed` 读数，'
            '`D5` 无从核对 —— 补一行「`flutter test` **N passed**」即可',
        isWarning: true,
      ),
    );
    return out;
  }
  if (actual != claimed) {
    out.add(
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: headLine,
        message: '头部写 `flutter test` $claimed 条，而 `STR` 最新轮次 $maxVer '
            '（$strFile:$maxLine）实跑 $actual 条',
      ),
    );
  }

  return out;
}

// ---------------------------------------------------------------------------
// D6 · 相对链接
// ---------------------------------------------------------------------------

/// `D6`：Markdown 里指向**仓内**的相对链接，目标路径必须存在。
///
/// 为什么要有这条：`D1`–`D5` 全在查「数对不对」，没有一条查「路对不对」。于是
/// 本仓真实踩过 —— 在 `docs/deliverables/01-plan/` 下写 `../design/00-index.md`
/// （正确是 `../../design/`），**三处全错而 `check.dart` 照样全绿**：那个目录在
/// `01-plan` 下不存在，但没人看链接。检查器不报的错，就只能等人翻到那一页才
/// 发现 —— 与 `D1`–`D5` 的失效模式一样，但更隐蔽（数字错了读者当场能看出来，
/// 链接坏了要点击才知道）。
///
/// 只查**相对路径**，三种目标一律跳过：
/// - **带 scheme 的**（`https:` / `mailto:` / `tel:`）：外链的可用性不是本仓的事，
///   而且检查外链要把 CI 变成网络依赖。
/// - **页内锚点**（`#…`）：锚点是否真实存在要解析标题 slug，判据本身有版本差异，
///   收益远低于代价。
/// - **站点绝对路径**（`/…`）：本仓的 Markdown 不经站点渲染，这种写法不成立，
///   但它是「渲染侧的事」，不是「文件在不在」的事。
///
/// 代码围栏内的链接同样跳过：文档里贴示例是常态，围栏里的路径本来就可能是
/// 占位符（`[x](path)`），校验它只会制造假红。
///
/// **目标是目录也算存在** —— `[参考层](reference/)` 是合法写法，判据是「这个
/// 路径在仓里能不能落地」，不是「它是不是文件」。
List<DocIssue> checkD6Links(DocContext c) => scanLinks(c).issues;

/// `D6` 的一趟扫描结果：查了几条、坏了几条。
///
/// 计数单独暴露，是因为「查了 749 条」与「0 处违规」是两句不同的话 —— 只报后者
/// 时，扫描范围意外塌成 0 条也是全绿。`check.dart` 把两个数一起打出来。
class LinkScan {
  const LinkScan({required this.checked, required this.issues});

  /// 真正判过存在性的条数（跳过外链 / 锚点 / 围栏之后）。
  final int checked;
  final List<DocIssue> issues;
}

/// 扫一遍全部 Markdown 的相对链接。
LinkScan scanLinks(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  int checked = 0;
  final List<String> files = c.markdown.keys.toList()..sort();
  for (final String file in files) {
    final List<String> lines = c.markdown[file]!.split('\n');
    bool inFence = false;
    for (int i = 0; i < lines.length; i++) {
      if (_fenceRe.hasMatch(lines[i])) {
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        continue;
      }
      // 行内代码同样跳过：`` `[参考层](reference/)` `` 这种写法是在**描述**链接
      // 语法本身（本仓 `STP` / `SCMP` 就这么写），不是一条真链接。剥成占位符再扫，
      // 链接文本里的反引号（`` [`x`](y) ``）不受影响 —— `](` 与目标仍在。
      final String scanLine = lines[i].replaceAll(_inlineCodeRe, '\u0000');
      for (final RegExpMatch m in _linkRe.allMatches(scanLine)) {
        final String raw = m.group(1)!;
        if (_isExternalTarget(raw)) {
          continue;
        }
        // 锚点跟在路径后面（`x.md#三`）：判存在只看路径那一段。
        final String target = raw.split('#').first;
        if (target.isEmpty || target.startsWith('/')) {
          continue;
        }
        checked++;
        final String? resolved = _resolveLink(file, target);
        if (resolved == null) {
          out.add(
            DocIssue(
              ruleId: 'D6',
              file: file,
              line: i + 1,
              message: '相对链接上跳越过仓库根：`$raw`',
            ),
          );
          continue;
        }
        if (!c.repoPaths.contains(resolved)) {
          out.add(
            DocIssue(
              ruleId: 'D6',
              file: file,
              line: i + 1,
              message: '相对链接指向不存在的路径：`$raw`（解析为 `$resolved`）',
            ),
          );
        }
      }
    }
  }
  return LinkScan(checked: checked, issues: out);
}

/// 行内链接 / 图片：`](目标)`。图片（`![alt](…)`）同样命中，两者都是路径承诺。
final RegExp _linkRe = RegExp(r'\]\(\s*([^)\s]+)\s*\)');

/// 代码围栏开闭行（三个反引号或三个波浪号，至多三格缩进）。
final RegExp _fenceRe = RegExp(r'^ {0,3}(?:```|~~~)');

/// 行内代码：成对的同数量反引号之间。
///
/// 必须支持**多反引号**定界（`` ``…`` ``）：描述「链接文本里带反引号」这类写法时
/// 就会用到，用单反引号的正则会把 `` `` [`x`](y) `` `` 剥成半截、剩下的 `](y)`
/// 被当成真链接 —— 实跑踩过一次，`STR` 里那处示例就此报假红。
final RegExp _inlineCodeRe = RegExp(r'(`+).*?\1');

/// 外链、页内锚点 —— 不判存在。
bool _isExternalTarget(String raw) {
  if (raw.startsWith('#')) {
    return true;
  }
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(raw);
}

/// 把 [target] 按 [fromFile] 所在目录解析成仓库相对路径。
///
/// 返回 `null` 表示**上跳越过仓库根**（`../../../x` 从 `docs/x.md` 出发）——
/// 那不是「链坏了」，是这条链接根本不可能指向仓内，单独给一句更准的话。
///
/// 不调 `package:path`：这一支是纯函数、零依赖，为十行逻辑引一个包不划算；
/// 也不解 `%20` 之类的百分号编码 —— 本仓路径一律直接写中文，没有编码形态，
/// 出现编码说明写法本身就不对，应当报出来而不是替它兜。
String? _resolveLink(String fromFile, String target) {
  final int slash = fromFile.lastIndexOf('/');
  final List<String> segs = slash < 0
      ? <String>[]
      : fromFile.substring(0, slash).split('/');
  for (final String part in target.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (segs.isEmpty) {
        return null;
      }
      segs.removeLast();
      continue;
    }
    segs.add(part);
  }
  return segs.join('/');
}

/// 报「实扫多/少了几条」，让日志能直接对上账。
String _delta(Set<String> scanned, int claimed) {
  final int diff = scanned.length - claimed;
  if (diff == 0) {
    return '';
  }
  return diff > 0 ? '（实扫多 $diff 条）' : '（实扫少 ${-diff} 条）';
}

// ---------------------------------------------------------------------------
// 工具
// ---------------------------------------------------------------------------

/// 按 `|` 切表格行，去掉首尾空段并 trim。
///
/// 转义的 `\|` 先换成占位符再切，切完换回来 —— 单元格里写 `a \| b` 时直接
/// `split('|')` 会多切出一列，整张表的列位就全错。
List<String> _splitRow(String line) {
  final String t = line.trim();
  if (!t.startsWith('|')) {
    return const <String>[];
  }
  const String placeholder = '\u0000PIPE\u0000';
  String body = t.replaceAll(r'\|', placeholder);
  body = body.substring(1);
  if (body.endsWith('|')) {
    body = body.substring(0, body.length - 1);
  }
  return body
      .split('|')
      .map((String s) => s.trim().replaceAll(placeholder, '|'))
      .toList();
}
