/// 交付物一致性检查器。
///
/// 用法（在 `app/` 下）：`dart run tool/docs/check.dart [仓库根]`
/// 退出码：0 无问题（警告不算）· 1 有违规 · 2 参数 / 目录错误。
///
/// 与 `tool/lint/check.dart` 分工：那支管**代码**的架构不变量（`R1`–`R5`），这支管
/// **四份交付物之间的口径**（`D1`–`D4`）。两支都要跑 —— `analyze` 与 `lint` 都看不见
/// 「`STD` 说 597 条、`STP` 分段展开 592 条」这类错。
///
/// 默认仓库根是 `..`（即在 `app/` 下执行）。CI 里 `app-checks` 的 `defaults` 就在
/// `app/`，所以这一行不用额外写 `working-directory`。
library;

import 'dart:io';

import 'rules.dart';

void main(List<String> args) {
  final List<String> positional =
      args.where((String a) => !a.startsWith('-')).toList();
  final String repoRoot = positional.isEmpty ? '..' : positional.first;

  if (!Directory(repoRoot).existsSync()) {
    stderr.writeln('[docs] 仓库根不存在：$repoRoot（请在 app/ 下执行）');
    exit(2);
  }

  final Map<String, String> docs = <String, String>{};
  for (final String rel in docFiles) {
    final File f = File('$repoRoot/$rel');
    if (!f.existsSync()) {
      // 缺文件不在读盘阶段退出：让 `D2` 报「文件不存在」，一处失败不掩其余。
      continue;
    }
    docs[rel] = f.readAsStringSync();
  }

  final Directory testDir = Directory('test');
  if (!testDir.existsSync()) {
    stderr.writeln('[docs] 测试目录不存在：test（请在 app/ 下执行）');
    exit(2);
  }
  final Map<String, String> tests = <String, String>{};
  final List<File> testFiles = testDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File f in testFiles) {
    final String rel = f.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^\./'), '');
    // `STD` 落点列写的是仓库相对路径（`app/test/...`），键跟着它走。
    tests['app/$rel'] = f.readAsStringSync();
  }

  final List<DocIssue> issues = checkAll(DocContext(docs: docs, tests: tests));

  final List<DocIssue> errors =
      issues.where((DocIssue i) => !i.isWarning).toList();
  final List<DocIssue> warnings =
      issues.where((DocIssue i) => i.isWarning).toList();

  for (final DocIssue i in <DocIssue>[...errors, ...warnings]) {
    stdout.writeln(i.toString());
  }
  stdout.writeln(
    '[docs] 检查 ${docs.length} 份交付物 · ${testFiles.length} 份测试文件，'
    '${errors.length} 处违规 · ${warnings.length} 处警告',
  );
  exit(errors.isEmpty ? 0 : 1);
}
