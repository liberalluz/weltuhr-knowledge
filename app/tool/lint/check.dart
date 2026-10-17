/// 架构规则检查器。
///
/// 用法（在 `app/` 下）：`dart run tool/lint/check.dart`
/// 退出码：0 无问题 · 1 有问题 · 2 参数 / 目录错误。
library;

import 'dart:io';

import 'rules.dart';

void main(List<String> args) {
  final String root = args.isEmpty ? 'lib' : args.first;
  final Directory dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('[lint] 目录不存在：$root（请在 app/ 下执行）');
    exit(2);
  }

  final List<File> files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

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
