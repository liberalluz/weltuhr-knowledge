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
/// `docs/specs/`，`str` 当时仍在原目录（`S7-2` 才出仓）。四份都在仓内，
/// 只是不再同目录 —— 所以路径只能逐条写死，不能按目录拼。
/// ⚠️ **2026-10-23 `S7-2`（`ADR-0009` §5）起是三份不是四份**：`STR` 已出仓，
/// 仓内不再有测试报告；读数改由 [stdFile] 的 §六「当前读数」单点登记。
/// 剩下三份都在 `docs/specs/`，但路径仍逐条写死 —— 按目录拼会在下次迁移时静默失配。
///
/// ⚠️ **2026-10-23 `ADR-0011` 起在 `docs/specs/` 下再分一层 `controlled/`**：
/// 受控交付物（有版号序列、受 `D2` 管）迁入 `docs/specs/controlled/`，其余活文档
/// 继续平铺在 `docs/specs/` 根。判据是「有没有版号序列」，不是文档主题。
/// **路径仍逐条写死**，理由同上 —— 这次搬家正是「按目录拼」会静默失配的又一例。
const List<String> docFiles = <String>[
  'docs/specs/controlled/scmp.md',
  'docs/specs/controlled/std.md',
  'docs/specs/controlled/stp.md',
];

const String scmpFile = 'docs/specs/controlled/scmp.md';
const String stdFile = 'docs/specs/controlled/std.md';
const String stpFile = 'docs/specs/controlled/stp.md';

/// `SDP` 已出仓（`S7-2` → 仓外 `process/sdp.md`）。`SDD` 仍在仓内，随 `ADR-0011`
/// 落在 `docs/specs/controlled/` —— 它是受控交付物但不是读数来源，故不进 [docFiles]。
const String sddFile = 'docs/specs/controlled/sdd.md';

/// 参与**版号自洽**的四份 = [docFiles] 三份 + `SDD`。
///
/// 为什么必须与 [docFiles] 分开：那条「只有三份」的理由是**它们互相登记读数**
/// （用例数、`flutter test` 读数），`SDD` 不参与读数口径，加进去会让
/// `D3` / `D4` 去它身上找用例表。但**版号自洽**是另一回事 ——
/// `SDD` 同样「历史节里列一串版号」，同样会脱节，
/// 而 `SCMP` §5.1 早就逐行登记了它。
///
/// 漏了它的代价是实测过的：`B13a` 笔 4 的摘要写「`SDD` 升 `v0.14.0`」，
/// 而 `SDD` 头部实际停在 `v0.13.0`、树里也缺本笔落下的八份新文件 ——
/// **两处一起没跟，`D2` 全程没报**，靠人工翻文件才发现。
///
/// ⚠️ **口径沿革**：六份（原）→ 五份（`S7-1` 移出 `SDP`）→ **四份（`S7-2` 移出
/// `STR`）**。每步都是「文件先离开仓内，规则后收窄」，顺序反了就会用旧口径报新结构的红。
const List<String> versionDocFiles = <String>[
  ...docFiles,
  sddFile,
];

/// 配置项标识 → 文件。`SCMP` §5.1 第三列以此开头。
///
/// `SDP` / `STR` 不在表内：二者已出仓，§5.1 里不再登记它们
/// （留在表里会给「登记了却没人查」的假保障）。
const Map<String, String> itemIdToFile = <String, String>{
  'SCMP': scmpFile,
  'STD': stdFile,
  'STP': stpFile,
  'SDD': sddFile,
};

final RegExp _versionRe = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');

/// 历史节标题。**只留一种写法**：`S7-2` 之前还有一支「`## 修订历史`」，专给当时仍在
/// `deliverables/` 的 `STR` —— 它出仓后，仓内参与版号自洽的四份一律是迁入 `specs/`
/// 后的新名。留着备选等于留一条永远不命中的分支，而「永远不命中的判据」在失效时
/// 与「没有判据」长得一样。
final RegExp _historyHeadRe = RegExp(r'^## 历史（迁移前版号序列）\s*$');
final RegExp _caseRowRe = RegExp(r'^\|\s*(?:~~)?`TC-[A-Z]+-\d+`');
final RegExp _ticketRe = RegExp(r'`(TC-[A-Z]+-\d+)`');
final RegExp _specRe = RegExp(r'([A-Z]{3,6})-\d{3}');

/// `STD` 里那个具名节的标题形态 —— `## 六、当前读数` 与 `## 当前读数` 都收。
///
/// `D5` 的锚点。行号会漂（剥版号、加摘要、调格式都会挪），节名不会。
final RegExp _readingHeadRe = RegExp(r'^##\s+.*当前读数');

/// 「当前读数」**节内**的取值：`` | `flutter test` | **414 passed** | ``。
/// 节内允许表格分隔符，故同一行任意字符都吃进来。
final RegExp _readingValueRe = RegExp(r'`flutter test`[^\n]*?\*\*(\d+)');

/// **节外**的严格读数形态：`` `flutter test` **414** ``（反引号后紧跟 `**N**`）。
///
/// 只认这个紧邻形态，是为了放过两类合法叙述：
/// 「`flutter test` 748 → 414」（变化叙述，没有闭合的 `**N**`）
/// 与「注射一处 `flutter test` 读数」（描述，数字不在紧邻位置）。
final RegExp _stdTestCountRe = RegExp(r'`flutter test`\s*\*\*(\d+)\*\*');

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
/// ⚠️ **取值来源换过两次，判据本身一次没换**：
///
/// - 原：读**头部**那一行（四份都带头部版号）。
/// - `S7-1`（`ADR-0009` §2 ③）：四份迁入 `docs/specs/` 并剥掉头部版号 ⇒ 改读
///   **历史节的语义最大版号**，被比的两端从「头部 vs 历史」变成「历史 vs `SCMP` §5.1」。
/// - `S7-2`：`STR` 出仓 ⇒ 覆盖面从五份降到**四份**，且第 1 条里「仍带头部版号的
///   那份」那一支随之删除（见下）。
///
/// 两个方向：
///
/// 1. **各自内部**：历史节必须存在、版号表必须非空、**且按版号严格降序**。
///    - 降序是 2026-10-23 立的新判据（规则文本在 `docs/AGENTS.md` 红线，六份表同批重排）。
///      此前各表的排序方向各走各的（`STD` / `STP` 升序、`SCMP` 前段降序后段升序、
///      `SDP` 尾部连续倒挂），`D2` 只能靠「取语义最大」绕开行序。
///    - **取值仍按语义最大、不读首行**：「表序对了」与「版号对了」是两件事；
///      让取值也依赖位置，等于用一个还没人守的约定去守另一个约定（`R-08`）。
///    - 两条必须一起：降序给出**唯一的插入位置**，否则「补录的旧版号该插哪」
///      每次都要现场判断，判断不一致就累积成交错序 —— 这正是旧表乱掉的原因。
/// 2. **`SCMP` §5.1 对四份**：表里 `SCMP` / `STD` / `STP` / `SDD` 四行的
///    版号，必须等于对应文件历史节的语义最大版号。这是**唯一一处**跨文件登记版号
///    的地方，它一旦滞后，读者按 §5.1 找基线就会找错。
///
/// ⚠️ **`S7-1` 曾把第 2 条降为 warning**（§5.1 要按新口径重排，不能让「表还没排完」
/// 拦红整条链），**`S7-2` 已恢复 `error`** —— §5.1 的三行已按出仓后重扫的结果写正，
/// 恢复后实测 0 报。
///
/// 覆盖范围是 [versionDocFiles] 四份而不是 [docFiles] 三份 —— `SDD` 同样会
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

    // 1) 历史节。`S7-2` 起仓内四份一律是迁入 `specs/` 后的标题形态。
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
          message: '找不到历史节（应为 `## 历史（迁移前版号序列）`）',
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

    // 3) 语义最大版号 + 降序校验。
    String? maxVer;
    String? prevVer;
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
      // 降序：本行必须**严格小于**上一行。相等也报 —— 同一版号占两行，等于
      // 同一版本被记了两次，读者无从判断哪条是准的（`SCMP` §5.1 的「同版号合并
      // 为一行」是同一条理由，只是那张表按份数合、这张表按版本合）。
      if (prevVer != null && _compareVersion(v, prevVer) >= 0) {
        out.add(
          DocIssue(
            ruleId: 'D2',
            file: f,
            line: i + 1,
            message: '历史表必须按版号降序（新行插表首）：$v 应排在 $prevVer 之前',
          ),
        );
      }
      prevVer = v;
      if (maxVer == null || _compareVersion(v, maxVer) > 0) {
        maxVer = v;
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

    // 4) ~~头部版号 vs 历史节最大版号~~ —— **`S7-2` 删除**。
    //
    //    这一步曾经只对 `STR` 生效（四份里唯一还带头部版号的一份）。`STR` 出仓后，
    //    仓内参与版号自洽的四份**全部剥了头部版号**，循环走到这里 `headVer` 恒为
    //    `null` —— 一个永远不执行的分支，与没有分支在失效时长得完全一样（`v0.72.0`
    //    删 `appliesTo.sixAxis` 恒真分支是同一条理由）。判据从「两处对账」降为
    //    「一处在表里、一处在历史节」：`§5.1` ↔ 历史节，见第 5 步。
  }

  // 5) SCMP §5.1：`| `vX.Y.Z` | 1 | `SCMP`（…` |
  //    `S7-1` 那次降级为 warning 是过渡措施，`S7-2` 已恢复 error —— 恢复的前提是
  //    §5.1 已按出仓后的实扫结果写正（22 份），否则规则一开就先红一片。
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
      // 第二列必须是纯数字（份数）；历史节的版号表行第二列是日期，靠这个分开。
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
                '历史节最大版号是 $actual',
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

/// `D5`：`flutter test` 读数**只登记一处** —— `STD` §六「当前读数」节。
///
/// **这条规则被重写过两次，每次都是「唯一来源换了地方」逼出来的：**
///
/// 1. **初版**判「`STD` 头部读数 == `STR` 最新轮次」，本意是补 `D1`–`D4` 都不管
///    头部的那类漏改。但它有结构性盲区：两处一起过期时两边相等，规则全绿。
///    `B13a` 笔 2 正是如此 —— 头部与轮次双双停在 `668`，真实 `679`，一次没报。
/// 2. **二版**改成「读数只写在 `STR` 轮次里，`STD` 头部再出现就报」，用结构消灭
///    对账。理由仍成立：同一个数写两处就有「一起错」的窗口，窗口里任何规则都
///    看不见，包括更聪明的规则。
/// 3. **本版（`S7-2`）**：`STR` 按 `ADR-0009` §5 出仓到仓外 `records/`，仓内不再
///    有测试报告 ⇒ 唯一来源必须搬回 `STD`。搬的方式不是「再写一个头部」，而是
///    **给它一个具名节**：`## 六、当前读数`。
///
/// **锚点为什么从「头部那一行」换成「一个具名节」**：行号会漂（剥版号、加摘要、
/// 调格式都会挪），节名不会。`S7-1` 剥版号时「读头部版号」那条正则（`_headVersionRe`，
/// `S7-2` 已删）在五份里一律不命中，`D5` 的锚点当场失效 —— 那次靠临时改读状态行
/// 顶住，但状态行同样是一行、同样会改。**教训不是「换个正则」，而是「锚点不要钉在
/// 会被人顺手重写的东西上」**。
///
/// **判据两条，缺一不可：**
/// 1. 该节必须存在，且节内登记了读数 —— 缺了等于整份文档集没人能说出当前是多少
///    （报 warning：信息损失，不是两个数打架）。
/// 2. **节外任何 Markdown 都不得出现严格读数形态** —— 包括 `SCMP` 头部状态、
///    包括本文件自己的用例表。这是「结构消灭」的落点：只有一个地方能写。
///
/// ⚠️ **允许的写法**：变化叙述「748 → 414」与描述「注射一处 `flutter test` 读数」。
/// 二者都不含紧邻的闭合 `**N**`，正则天然不命中 —— 这不是巧合，`TC-DOC-015` 守这个负例。
/// 防误报比防漏报更要紧：一条会误报的规则活不过三次改动。
List<DocIssue> checkD5TestCount(DocContext c) {
  final List<DocIssue> out = <DocIssue>[];
  final String? stdText = c.docs[stdFile];
  if (stdText == null) {
    return const <DocIssue>[
      DocIssue(ruleId: 'D5', file: stdFile, line: 0, message: '文件不存在'),
    ];
  }

  final List<String> stdLines = stdText.split('\n');

  // 1) 定位「当前读数」节，并算出它的行范围。
  int secStart = -1;
  for (int i = 0; i < stdLines.length; i++) {
    if (_readingHeadRe.hasMatch(stdLines[i])) {
      secStart = i;
      break;
    }
  }
  if (secStart < 0) {
    return <DocIssue>[
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: 0,
        message: '找不到「## 当前读数」节 —— 它是全仓唯一的执行读数登记处，'
            '缺了就没有任何一处能说出 `flutter test` 当前是多少',
        isWarning: true,
      ),
    ];
  }
  int secEnd = stdLines.length;
  for (int i = secStart + 1; i < stdLines.length; i++) {
    if (stdLines[i].startsWith('## ')) {
      secEnd = i;
      break;
    }
  }

  // 2) 节内必须真的登记了读数 —— 空节比没有节更坏：它让人以为登记过。
  bool found = false;
  for (int i = secStart; i < secEnd; i++) {
    if (_readingValueRe.hasMatch(stdLines[i])) {
      found = true;
      break;
    }
  }
  if (!found) {
    out.add(
      DocIssue(
        ruleId: 'D5',
        file: stdFile,
        line: secStart + 1,
        message: '「当前读数」节里没有 `flutter test` 读数 —— 这一节是全仓唯一'
            '来源，空着等于没人能说出当前是多少。补一行'
            '「| `flutter test` | **N passed** | 采集方式 |」即可',
        isWarning: true,
      ),
    );
  }

  // 3) 节外不得出现严格读数形态 —— 全仓扫，不只本文件。
  //
  // 为什么必须全仓：读数还会出现在别的文件的**头部状态行**里（`SCMP` 就写过）。
  // 只查 `STD` 等于把「别的文件替你登记读数的入口」留着，而那正是「一起过期」
  // 的成因 —— 两个地方都能写，就一定会两处都写。
  //
  // ⚠️ 扫描面 = `markdown` ∪ `docs`，**不是**只用 `markdown`：生产里 `check.dart`
  // 两个都给，`docs` 是 `markdown` 的子集，并集看不出差别；但调用方少喂一个
  // （比如只构造交付物夹具）时，`STD` 自己的头部就掉出扫描面 —— 规则静默少查一份，
  // 而它正是最容易写错的那一份。这类「输入缺一块、判据照样绿」的形态，本仓已经
  // 在 `D5` 上一版（`STR` `R15a` 双双停在 668）付过一次代价。
  final Map<String, String> all = <String, String>{...c.markdown};
  c.docs.forEach((String k, String v) => all.putIfAbsent(k, () => v));
  final List<String> keys = all.keys.toList()..sort();
  for (final String path in keys) {
    final List<String> lines = all[path]!.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (path == stdFile && i >= secStart && i < secEnd) {
        continue;
      }
      final RegExpMatch? dup = _stdTestCountRe.firstMatch(lines[i]);
      if (dup == null) {
        continue;
      }
      out.add(
        DocIssue(
          ruleId: 'D5',
          file: path,
          line: i + 1,
          message: '读数 `flutter test` **${dup.group(1)}** 出现在「当前读数」'
              '节之外 —— 它是全仓唯一登记处（`STD` §六）。同一个数写两个地方'
              '就有「一起过期」的窗口，窗口里这条规则看不见（`STR` `R15a` 实证：'
              '头部与轮次双双停在 668，真实 679）。删掉本处即可；变化叙述写'
              '「748 → 414」不会被判成读数',
        ),
      );
    }
  }

  return out;
}


// ---------------------------------------------------------------------------
// D6 · 相对链接
// ---------------------------------------------------------------------------

/// `D6`：Markdown 里指向**仓内**的相对链接，目标路径必须存在。
///
/// 为什么要有这条：`D1`–`D5` 全在查「数对不对」，没有一条查「路对不对」。于是
/// 本仓真实踩过 —— 在 `deliverables/01-plan/`（`S7-3` 已删）下写 `../design/00-index.md`
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
