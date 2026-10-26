/// `tool/docs` 的安全自动修复。
///
/// 只修**能从现有正文唯一推导**的两类值：
///   - `D3`：`STD` 头部 `§三 用例表 **N 条**` 与 `STP` §5.1 合计行 —— N 由
///     `STD` 用例表的唯一 `TC-*` 编号数得出。
///   - `D2`：`SCMP` §5.1 登记的 `SCMP` / `STD` / `STP` / `SDD` 版号 —— 取各文件
///     「历史（迁移前版号序列）」表的语义最大版号。
///
/// 不自动修：`D1` 落点、`D4` 覆盖统计、`D6` 链接、`D7` 头部文字。它们的“正确值”
/// 不是从另一处唯一推导出来的，自动改只会把错藏得更深。
library;

import 'dart:io';

import 'rules.dart';

class FixResult {
  FixResult({required this.changes, required this.errors});

  final List<String> changes;
  final List<String> errors;

  bool get changed => changes.isNotEmpty;
}

final RegExp _versionRe = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');
final RegExp _caseRowRe = RegExp(r'^\|\s*(?:~~)?`TC-[A-Z]+-\d+`');
final RegExp _ticketRe = RegExp(r'`(TC-[A-Z]+-\d+)`');
final RegExp _historyHeadRe = RegExp(r'^## 历史（迁移前版号序列）\s*$');

FixResult applyFixes(String repoRoot, Map<String, String> docs) {
  final List<String> changes = <String>[];
  final List<String> errors = <String>[];

  final String? std = docs[stdFile];
  final Set<String> ids = <String>{};
  if (std == null) {
    errors.add('$stdFile 不存在，无法计算用例数');
  } else {
    for (final String line in std.split('\n')) {
      if (_caseRowRe.hasMatch(line)) {
        final RegExpMatch? m = _ticketRe.firstMatch(line);
        if (m != null) ids.add(m.group(1)!);
      }
    }
    if (ids.isEmpty) {
      errors.add('$stdFile 没有可识别的 TC-* 用例行，拒绝自动改用例数');
    } else {
      _fixStdHeader(docs, ids.length, changes, errors);
    }
  }

  if (ids.isNotEmpty) {
    _fixStpTotal(docs, ids.length, changes, errors);
  }

  final Map<String, String> latest = _latestVersions(docs, errors);
  if (latest.isNotEmpty) {
    _fixScmpVersions(docs, latest, changes, errors);
  }

  for (final String file
      in changes.map((String c) => c.split(':').first).toSet()) {
    final String? text = docs[file];
    if (text != null) {
      File('$repoRoot/$file').writeAsStringSync(text);
    }
  }

  return FixResult(changes: changes, errors: errors);
}

void _fixStdHeader(
  Map<String, String> docs,
  int count,
  List<String> changes,
  List<String> errors,
) {
  final String? text = docs[stdFile];
  if (text == null) return;
  final RegExp re = RegExp(r'(§三 用例表 \*\*)(\d+)( 条\*\*)');
  final RegExpMatch? m = re.firstMatch(text);
  if (m == null) {
    errors.add('$stdFile 找不到「§三 用例表 **N 条**」，无法自动改');
    return;
  }
  if (int.parse(m.group(2)!) == count) return;
  docs[stdFile] = text.replaceFirstMapped(
    re,
    (Match x) => '${x.group(1)}$count${x.group(3)}',
  );
  changes.add('$stdFile: §三 用例表 ${m.group(2)} → $count 条');
}

void _fixStpTotal(
  Map<String, String> docs,
  int count,
  List<String> changes,
  List<String> errors,
) {
  final String? text = docs[stpFile];
  if (text == null) return;
  final List<String> lines = text.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final List<String> cells = lines[i].split('|');
    if (cells.length < 4 || cells[1].trim() != '**合计**') continue;
    final RegExpMatch? m = RegExp(r'^\s*\*\*(\d+)\*\*\s*$')
        .firstMatch(cells[2]);
    if (m == null) continue;
    if (int.parse(m.group(1)!) == count) return;
    cells[2] = ' **$count** ';
    lines[i] = cells.join('|');
    docs[stpFile] = lines.join('\n');
    changes.add('$stpFile: §5.1 合计 ${m.group(1)} → $count 条');
    return;
  }
  errors.add('$stpFile 找不到 `| **合计** | **N** |` 行，无法自动改');
}

Map<String, String> _latestVersions(
  Map<String, String> docs,
  List<String> errors,
) {
  final Map<String, String> latest = <String, String>{};
  for (final String file in versionDocFiles) {
    final String? text = docs[file];
    if (text == null) continue;
    final List<String> lines = text.split('\n');
    int section = -1;
    for (int i = 0; i < lines.length; i++) {
      if (_historyHeadRe.hasMatch(lines[i])) {
        section = i;
        break;
      }
    }
    if (section < 0) {
      errors.add('$file 找不到历史节，无法自动修 §5.1 版号');
      continue;
    }
    int sectionEnd = lines.length;
    for (int i = section + 1; i < lines.length; i++) {
      if (lines[i].startsWith('## ')) {
        sectionEnd = i;
        break;
      }
    }
    String? max;
    for (int i = section + 1; i < sectionEnd; i++) {
      final List<String> cells = lines[i].split('|');
      if (cells.length < 2) continue;
      final String v = cells[1].trim().replaceAll('`', '');
      if (_versionRe.firstMatch(v) == null) continue;
      if (max == null || _compare(v, max) > 0) max = v;
    }
    if (max != null) latest[file] = max;
  }
  return latest;
}

void _fixScmpVersions(
  Map<String, String> docs,
  Map<String, String> latest,
  List<String> changes,
  List<String> errors,
) {
  final String? text = docs[scmpFile];
  if (text == null) return;
  final List<String> lines = text.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final List<String> cells = lines[i].split('|');
    if (cells.length < 4) continue;
    final String ver = cells[1].trim().replaceAll('`', '');
    if (_versionRe.firstMatch(ver) == null) continue;
    if (!RegExp(r'^\d+$').hasMatch(cells[2].trim())) continue;
    final RegExpMatch? idm = RegExp(r'`([A-Z]+)`').firstMatch(cells[3]);
    if (idm == null) continue;
    final String? target = itemIdToFile[idm.group(1)!];
    if (target == null) continue;
    final String? actual = latest[target];
    if (actual == null || actual == ver) continue;
    cells[1] = ' `$actual` ';
    lines[i] = cells.join('|');
    changes.add('$scmpFile: §5.1 ${idm.group(1)} $ver → $actual');
  }
  if (changes.isNotEmpty) docs[scmpFile] = lines.join('\n');
  if (lines.isNotEmpty && latest.isEmpty) {
    errors.add('$scmpFile 有 §5.1 登记，但没有读到任何历史版号');
  }
}

int _compare(String a, String b) {
  final List<int> pa = _parse(a);
  final List<int> pb = _parse(b);
  for (int i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

List<int> _parse(String v) {
  final RegExpMatch? m = _versionRe.firstMatch(v);
  if (m == null) return <int>[0, 0, 0];
  return <int>[
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  ];
}
