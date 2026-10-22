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

import 'markdown_links.dart';

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
/// 只有这四份：它们之间**互相登记对方的版号与读数**（`SCMP` §5.1 登五份的版号，
/// `STD` 声明用例数、`STP` 汇总同一个数）。其余交付物单向来引，不构成环，没有
/// 「两处写同一个数」的问题。
///
/// ⚠️ 「版号自洽」不适用这条限制 —— 见 [versionDocFiles]。
///
/// ⚠️ **2026-10-22 `S7-1`（`ADR-0009`）后路径三分**：`scmp` / `std` / `stp` 已迁入
/// `docs/specs/`，`str` 仍在 `docs/deliverables/`（`S7-2` 才出仓）。四份都在仓内，
/// 只是不再同目录 —— 所以路径只能逐条写死，不能按目录拼。
const List<String> docFiles = <String>[
  'docs/specs/scmp.md',
  'docs/specs/std.md',
  'docs/specs/stp.md',
  'docs/deliverables/04-test/STR-软件测试报告.md',
];

const String scmpFile = 'docs/specs/scmp.md';
const String stdFile = 'docs/specs/std.md';
const String stpFile = 'docs/specs/stp.md';
const String strFile = 'docs/deliverables/04-test/STR-软件测试报告.md';

/// `SDP` 仍留在 `deliverables/`（`S7-2` 出仓），但**已退出 `D2` 的对账范围** ——
/// 它讲里程碑与资源，与代码内容零耦合，没有「改代码时必须同时改」的读数。
const String sdpFile = 'docs/deliverables/01-plan/SDP-软件开发计划.md';
const String sddFile = 'docs/specs/sdd.md';

/// 参与**版号自洽**的五份 = [docFiles] 四份 + `SDD`。
///
/// 为什么必须与 [docFiles] 分开：那条「只有四份」的理由是**它们互相登记读数**
/// （用例数、`flutter test` 读数），`SDD` 不参与读数口径，加进去会让
/// `D3` / `D4` / `D5` 去它身上找用例表。但**版号自洽**是另一回事 ——
/// `SDD` 同样「历史节里列一串版号」，同样会脱节，
/// 而 `SCMP` §5.1 早就逐行登记了它。
///
/// 漏了它的代价是实测过的：`B13a` 笔 4 的摘要写「`SDD` 升 `v0.14.0`」，
/// 而 `SDD` 头部实际停在 `v0.13.0`、树里也缺本笔落下的八份新文件 ——
/// **两处一起没跟，`D2` 全程没报**，靠人工翻文件才发现。
///
/// ⚠️ **`S7-1` 起是五份不是六份**：`SDP` 出仓在即（`S7-2`），本批先把它移出对账
/// 范围 —— 否则「已经不算受控」的文件仍在报红，等于用旧口径卡新结构。
const List<String> versionDocFiles = <String>[
  ...docFiles,
  sddFile,
];

/// 配置项标识 → 文件。`SCMP` §5.1 第三列以此开头。
///
/// `SDP` 不在表内：它已退出 [versionDocFiles]，§5.1 里那一行不再对账
/// （仍留在表里会给「登记了却没人查」的假保障）。
const Map<String, String> itemIdToFile = <String, String>{
  'SCMP': scmpFile,
  'STD': stdFile,
  'STP': stpFile,
  'STR': strFile,
  'SDD': sddFile,
};

final RegExp _versionRe = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');
final RegExp _headVersionRe = RegExp(r'^> \*\*版号\*\*：`(v\d+\.\d+\.\d+)`');

/// `D5` 的锚点：头部**状态行**。
///
/// ⚠️ `S7-1` 剥掉五份头部版号片段后，`_headVersionRe` 在五份里一律不命中 ——
/// `D2` 的处置是换取值来源（改读历史节），`D5` 的处置是换锚点（改读状态行），
/// 两条规则吃同一个正则却是**两种失效方式**（取值来源没了 vs 定位锚点没了）。
final RegExp _headStateRe = RegExp(r'^> \*\*状态\*\*：');

/// 历史节标题的两种写法：迁入 `specs/` 的用新名，仍在 `deliverables/` 的用旧名。
final RegExp _historyHeadRe =
    RegExp(r'^## (?:历史（迁移前版号序列）|修订历史)\s*$');
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

/// `D2`：五份文件的版号必须自洽。
///
/// ⚠️ **`S7-1` 起取值来源换了**（`ADR-0009` 决策 §2 ③）：四份已迁入 `docs/specs/`
/// 并剥掉头部版号，「读头部那一行」不再成立。取值统一改为**读历史节的语义最大
/// 版号** —— 判据语义不变（仍是「同一个版号不能两处不一致」），只是被比的两端
/// 从「头部 vs 历史」改成「历史 vs `SCMP` §5.1」。
///
/// 两个方向：
///
/// 1. **各自内部**：历史节必须存在、版号表必须非空；**仍带头部版号的那份**
///    （`str`，`S7-2` 才出仓）头部必须等于历史节的最大版号。
///    取最大值而不是「最后一行」—— 表的排序方向并不统一（`STD` / `STP` 升序、
///    `SCMP` 前段降序后段升序、`STR` 中间还夹着 `v0.18.0` 在 `v0.17.0` 前面），
///    依赖位置就得先修表；而修表是另一件事，不该挡住这条检查。
/// 2. **`SCMP` §5.1 对五份**：表里 `SCMP` / `STD` / `STP` / `STR` / `SDD` 五行的
///    版号，必须等于对应文件历史节的语义最大版号。这是**唯一一处**跨文件登记版号
///    的地方，它一旦滞后，读者按 §5.1 找基线就会找错。
///
/// ⚠️ **本批（`S7-1`）第 2 条降为 warning**：§5.1 的六行要按新口径重算，降级是
/// 为了不让「表还没重排完」把整条链拦红（`ADR-0009` 决策记录第三批第 3 项）。
/// **`S7-2` 恢复 `error`** —— 恢复时删掉那处 `isWarning: true` 即可，判据本身不要再改。
///
/// 覆盖范围是 [versionDocFiles] 五份而不是 [docFiles] 四份 —— `SDD` 同样会
/// 「历史与登记脱节」，而它恰恰是最长、最少被翻的一份（详见 [versionDocFiles]）。
List<DocIssue> checkD2Versions(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  // 文件 → 历史节的语义最大版号。§5.1 的对账用它，不再用头部。
  final Map<String, String> latest = <String, String>{};

  for (final String f in versionDocFiles) {
    final String? text = c.docs[f];
    if (text == null) {
      out.add(DocIssue(ruleId: 'D2', file: f, line: 0, message: '文件不存在'));
      continue;
    }
    final List<String> lines = text.split('\n');

    // 1) 历史节。迁入 `specs/` 的五份叫「历史（迁移前版号序列）」，
    //    仍在 `deliverables/` 的（`str`）还叫「修订历史」—— 两种都收。
    int section = -1;
    for (int i = 0; i < lines.length; i++) {
      if (_historyHeadRe.hasMatch(lines[i])) {
        section = i;
        break;
      }
    }
    if (section < 0) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: 0,
          message: '找不到历史节（应为 `## 历史（迁移前版号序列）` 或 `## 修订历史`）',
        ),
      );
      continue;
    }
    // 节的范围 = 标题之后，到下一个二级标题或文件末尾。
    int sectionEnd = lines.length;
    for (int i = section + 1; i < lines.length; i++) {
      if (lines[i].startsWith('## ')) {
        sectionEnd = i;
        break;
      }
    }

    // 2) 节内的版号表（表头首列是「版号」的那张）。
    int start = -1;
    for (int i = section + 1; i < sectionEnd; i++) {
      final List<String> cells = _splitRow(lines[i]);
      if (cells.isNotEmpty && cells.first == '版号') {
        start = i;
        break;
      }
    }
    if (start < 0) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: section + 1,
          message: '历史节里找不到版号表（表头首列应为「版号」）',
        ),
      );
      continue;
    }

    // 3) 语义最大版号。
    String? maxVer;
    int maxLine = 0;
    int rows = 0;
    for (int i = start + 1; i < sectionEnd; i++) {
      if (!lines[i].trim().startsWith('|')) {
        break;
      }
      final List<String> cells = _splitRow(lines[i]);
      if (cells.isEmpty) {
        continue;
      }
      final String v = cells.first.replaceAll('`', '');
      if (_versionRe.firstMatch(v) == null) {
        continue;
      }
      rows++;
      if (maxVer == null || _compareVersion(v, maxVer) > 0) {
        maxVer = v;
        maxLine = i + 1;
      }
    }
    if (maxVer == null || rows == 0) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: start + 1,
          message: '历史节的版号表为空',
        ),
      );
      continue;
    }
    latest[f] = maxVer;

    // 4) 头部仍带版号的文件（`str`）：两者必须一致。剥掉版号的那几份没有头部左值，
    //    这一步自然跳过 —— 不是「放行」，而是「比的两端只剩历史与 §5.1」。
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
    if (headVer != null && headVer != maxVer) {
      out.add(
        DocIssue(
          ruleId: 'D2',
          file: f,
          line: headLine,
          message: '头部版号 $headVer 与历史节最大版号 $maxVer 不一致'
              '（后者在 $f:$maxLine）',
        ),
      );
    }
  }

  // 5) SCMP §5.1：`| `vX.Y.Z` | 1 | `SCMP`（…` |
  //    ⚠️ 本批降为 warning；`S7-2` 恢复 error（删 isWarning 即可）。
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
      final String? actual = latest[target];
      if (actual != null && actual != ver) {
        out.add(
          DocIssue(
            ruleId: 'D2',
            file: scmpFile,
            line: i + 1,
            message: '§5.1 登记 $id 为 $ver，而 ${target.split('/').last} '
                '历史节最大版号是 $actual（本批降为 warning，`S7-2` 恢复 error）',
            isWarning: true,
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
// D5 · 读数单点
// ---------------------------------------------------------------------------

/// `D5`：`flutter test` 读数**只登记一处** —— `STR` 的最新轮次。
///
/// **这条规则原来长什么样、为什么改**：先前判的是「`STD` 头部读数 == `STR` 最新
/// 轮次」，本意是补 `D1`–`D4` 都不管头部的那一类漏改（实测 `v0.44.0` 的 561、
/// `v0.45.0` 的 572 连续两版没写进头部）。但它有一个**结构性盲区**：两处一起
/// 过期时两边相等，规则全绿。`B13a` 笔 2 正是如此 —— `STD` 头部与轮次 `R15a`
/// 双双停在 `668`，真实读数 `679`，一次都没报（见 `STR` `R15a` 的「顺带修掉
/// 一处漏登」）。
///
/// **为什么不是「把规则写得更聪明」**：判据的可靠性取决于有没有**第三方锚**。
/// `flutter test` 是执行读数，在文档内部无法复算 —— `D3` 数的是用例表行数，
/// 而 608 行用例 ≠ 572 条 Dart 测试（两个口径本来就不同），硬拉在一起只会让
/// 两条规则一起说谎。只要同一个数写两处，就存在「一起错」的窗口；窗口里任何
/// 规则都看不见，包括更聪明的规则。
///
/// **所以改成结构消灭**：读数只写在 `STR` 的轮次记录里，`STD` 头部再出现同形态
/// 读数就报。这与本仓已有的先例同源 —— `STD` 头部的覆盖缺口读数早就「只在 §4.1
/// 一处维护，本行不复制」，理由就写在同一行里：能不对账就不需要对账。
///
/// ⚠️ **允许的写法**：变化叙述「748 → 414」。它不含闭合的 `**N**`，
/// `_stdTestCountRe` 天然不命中 —— 这不是巧合，`TC-DOC-015` 专门守这个负例。
/// 防误报比防漏报更要紧：一条会误报的规则活不过三次改动。
///
/// 保留另一半判据：「`STR` 最新轮次必须登记 `… passed`」。它现在是**唯一**来源，
/// 缺了就等于整份文档集没人能说出当前读数 —— 报 warning（信息损失，不是两数打架）。
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

  // 1) `STD` 头部不得再出现读数 —— 它只该在 `STR` 的轮次里。
  //
  // ⚠️ 锚点 `S7-1` 换过一次：原先靠「头部版号行」定位这一行，剥掉版号片段后
  // 该正则不再命中（`D2` 与 `D5` 吃同一个正则，失效方式却不同 —— 前者是取值
  // 来源没了、后者是定位锚点没了）。这里改用头部**状态行**，检查范围仍是
  // 「头部那一行」。真正的判据重写（把读数收进 `STD` 的「当前读数」节）属
  // `S7-2`，与 `STR` 出仓同批 —— 本批只换锚点，语义一字未动。
  final List<String> stdLines = stdText.split('\n');
  int headLine = 0;
  for (int i = 0; i < stdLines.length; i++) {
    if (!_headStateRe.hasMatch(stdLines[i])) {
      continue;
    }
    headLine = i + 1;
    break;
  }
  if (headLine == 0) {
    return const <DocIssue>[
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: 0,
        message: '找不到头部状态行（应为 `> **状态**：…`），无从检查读数是否只登记一处',
      ),
    ];
  }
  final RegExpMatch? dup = _stdTestCountRe.firstMatch(stdLines[headLine - 1]);
  if (dup != null) {
    out.add(
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: headLine,
        message: '头部仍写 `flutter test` **${dup.group(1)}** —— 读数只登记在 `STR` '
            '最新轮次一处。同一个数写两处就有「一起过期」的窗口，窗口里这条规则'
            '看不见（`STR` `R15a` 实证：头部与轮次双双停在 668，真实 679）。'
            '删掉本处即可；变化叙述写「748 → 414」不会被判成读数',
      ),
    );
  }

  // 2) `STR` 最新轮次必须登记读数 —— 它现在是唯一来源。
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
        message: '`STR` 最新轮次（$maxVer）未登记 `… passed` 读数 —— 它现在是全仓'
            '唯一的读数来源，缺了就没有任何一处能说出当前是多少。补一行'
            '「`flutter test` **N passed**」即可',
        isWarning: true,
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
      if (fenceRe.hasMatch(lines[i])) {
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        continue;
      }
      // 行内代码同样跳过：`` `[参考层](reference/)` `` 这种写法是在**描述**链接
      // 语法本身（本仓 `STP` / `SCMP` 就这么写），不是一条真链接。剥成占位符再扫，
      // 链接文本里的反引号（`` [`x`](y) ``）不受影响 —— `](` 与目标仍在。
      final String scanLine = lines[i].replaceAll(inlineCodeRe, '\u0000');
      for (final RegExpMatch m in linkRe.allMatches(scanLine)) {
        final String raw = m.group(1)!;
        if (isExternalTarget(raw)) {
          continue;
        }
        // 锚点跟在路径后面（`x.md#三`）：判存在只看路径那一段。
        final String target = raw.split('#').first;
        if (target.isEmpty || target.startsWith('/')) {
          continue;
        }
        checked++;
        final String? resolved = resolveLink(file, target);
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

/// 链接的正则与路径解析已抽到 [`markdown_links.dart`](markdown_links.dart) ——
/// 迁移器（`migrate_docs.dart`）必须与 `D6` 同口径，各写一份必然漂移。

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
