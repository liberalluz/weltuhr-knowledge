import 'dart:io';

import '../../tool/docs/fix.dart';
import '../../tool/docs/rules.dart';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _fixture() => <String, String>{
  scmpFile: '''
> **状态**：ok

| 版号 | 份数 | 配置项 |
|---|---|---|
| `v0.1.0` | 1 | `SCMP`（x） |
| `v0.1.0` | 1 | `STD`（x） |
| `v0.1.0` | 1 | `STP`（x） |
| `v0.1.0` | 1 | `SDD`（x） |

## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.2.0` | 2026-10-26 | current |
| `v0.1.0` | 2026-10-17 | first |
''',
  stdFile: '''
> **状态**：§三 用例表 **3 条**

## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.2.0` | 2026-10-26 | current |
| `v0.1.0` | 2026-10-17 | first |

| 编号 | `SPEC` | 显式/语义 | 夹具 | 操作 | 预期 | 层级 | 落点 / 测试名 |
|---|---|---|---|---|---|---|---|
| `TC-FND-001` | `FND-001` | 显式 | — | — | — | Unit | `app/test/a_test.dart` · `甲` |
| `TC-FND-002` | `FND-001` | 语义 | — | — | — | Unit | 同上 · `乙` |
''',
  stpFile: '''
> **状态**：ok

## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.2.0` | 2026-10-26 | current |
| `v0.1.0` | 2026-10-17 | first |

| 层 | 用例数 | 编号 | 跑法 |
|---|---|---|---|
| Unit | 3 | `TC-FND-001`–`002` | x |

| **合计** | **3** | — | — |
''',
  sddFile: '''
## 历史（迁移前版号序列）

| 版号 | 日期 | 修订摘要 |
|---|---|---|
| `v0.2.0` | 2026-10-26 | current |
| `v0.1.0` | 2026-10-17 | first |
''',
};

void _write(Directory root, Map<String, String> docs) {
  for (final MapEntry<String, String> e in docs.entries) {
    final File f = File('${root.path}/${e.key}');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(e.value);
  }
}

void main() {
  test('fix D3 counts and SCMP versions（无 SPEC：docs --fix 工具回归）', () {
    final Directory root = Directory.systemTemp.createTempSync('docs-fix-');
    addTearDown(() => root.deleteSync(recursive: true));
    final Map<String, String> docs = _fixture();
    _write(root, docs);

    final FixResult result = applyFixes(root.path, docs);
    expect(result.errors, isEmpty);
    expect(result.changes.length, 6);

    final String std = File('${root.path}/$stdFile').readAsStringSync();
    expect(std, contains('§三 用例表 **2 条**'));
    final String stp = File('${root.path}/$stpFile').readAsStringSync();
    expect(stp, contains('| **合计** | **2** | — | — |'));
    final String scmp = File('${root.path}/$scmpFile').readAsStringSync();
    expect(scmp, contains('`v0.2.0` | 1 | `SCMP`'));
    expect(scmp, contains('`v0.2.0` | 1 | `SDD`'));
  });

  test('already consistent fixture is untouched（无 SPEC：docs --fix 工具回归）', () {
    final Directory root = Directory.systemTemp.createTempSync('docs-fix-');
    addTearDown(() => root.deleteSync(recursive: true));
    final Map<String, String> docs = _fixture();
    docs[stdFile] = docs[stdFile]!.replaceFirst('**3 条**', '**2 条**');
    docs[stpFile] = docs[stpFile]!.replaceFirst('**3**', '**2**');
    for (final String id in <String>['SCMP', 'STD', 'STP', 'SDD']) {
      docs[scmpFile] = docs[scmpFile]!.replaceFirst(
        '`v0.1.0` | 1 | `$id`',
        '`v0.2.0` | 1 | `$id`',
      );
    }
    _write(root, docs);

    final FixResult result = applyFixes(root.path, docs);
    expect(result.changes, isEmpty);
    expect(result.errors, isEmpty);
  });

  test(
    'missing history is reported and not guessed（无 SPEC：docs --fix 工具回归）',
    () {
      final Directory root = Directory.systemTemp.createTempSync('docs-fix-');
      addTearDown(() => root.deleteSync(recursive: true));
      final Map<String, String> docs = _fixture();
      docs[stdFile] = docs[stdFile]!.split('## 历史（迁移前版号序列）').first;
      _write(root, docs);

      final FixResult result = applyFixes(root.path, docs);
      expect(result.errors.any((String e) => e.contains('找不到历史节')), isTrue);
    },
  );
}
