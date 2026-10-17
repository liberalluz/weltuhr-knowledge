/// 架构规则检查器。
///
/// 用法（在 `app/` 下）：`dart run tool/lint/check.dart [目录…]`
/// 退出码：0 无问题 · 1 有问题 · 2 参数 / 目录错误。
///
/// 默认扫 `lib` 与 `test` 两个目录：`R1`–`R4` 管 `lib/`，`R5` 只管 `test/`。
/// 只扫 `lib` 会把「测试有没有标裁定来源」这条漏掉 —— 而它正是 `R-09` 的落点。
library;

import 'dart:io';

import 'rules.dart';

void main(List<String> args) {
  final List<String> roots = args.isEmpty ? <String>['lib', 'test'] : args;

  final List<File> files = <File>[];
  for (final String root in roots) {
    final Directory dir = Directory(root);
    if (!dir.existsSync()) {
      stderr.writeln('[lint] 目录不存在：$root（请在 app/ 下执行）');
      exit(2);
    }
    files.addAll(
      dir.listSync(recursive: true).whereType<File>().where((File f) => f.path.endsWith('.dart')),
    );
  }
  files.sort((File a, File b) => a.path.compareTo(b.path));

  final issues = <LintIssue>[];
  for (final File file in files) {
    issues.addAll(checkSource(path: file.path, source: file.readAsStringSync()));
  }

  for (final LintIssue issue in issues) {
    stdout.writeln(issue.toString());
  }
  stdout.writeln('[lint] 扫描 ${files.length} 个文件，${issues.length} 处违规');
  exit(issues.isEmpty ? 0 : 1);
}
