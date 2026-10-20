/// 交付物一致性检查器。
///
/// 用法（在 `app/` 下）：`dart run tool/docs/check.dart [仓库根]`
/// 退出码：0 无问题（警告不算）· 1 有违规 · 2 参数 / 目录错误。
///
/// 与 `tool/lint/check.dart` 分工：那支管**代码**的架构不变量（`R1`–`R5`），这支管
/// **四份交付物之间的口径**（`D1`–`D5`）与**全仓 Markdown 的相对链接**（`D6`）。
/// 两支都要跑 —— `analyze` 与 `lint` 都看不见「`STD` 说 597 条、`STP` 分段展开 592 条」
/// 这类错，也看不见「链接指到不存在的文件」。
///
/// `D6` 的输入与 `D1`–`D5` 不同源：`D1`–`D5` 只读四份交付物与 `test/`，`D6` 要
/// **全仓**的 Markdown 与路径清单。两趟分开走，互不影响 —— 前者读不到的缺文件由
/// `D2` 报「文件不存在」，后者读不到的目录直接跳过。
///
/// 默认仓库根是 `..`（即在 `app/` 下执行）。CI 里 `app-checks` 的 `defaults` 就在
/// `app/`，所以这一行不用额外写 `working-directory`。
library;

import 'dart:io';

import 'rules.dart';

/// `D6` 遍历时整棵跳过的目录。
///
/// `tmp/` 刻意在内：那是 PR 正文与提交信息的草稿，里面的相对链接是**待贴到别处**的，
/// 不承诺在本仓可落地。`ios/Runner/.../LaunchImage.imageset/README.md` 之类由工具
/// 生成的说明也不在排除表里 —— 它们若带相对链接，本来就该是对的。
const Set<String> linkSkipDirs = <String>{
  '.git',
  '.dart_tool',
  '.idea',
  'build',
  'node_modules',
  'tmp',
};

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

  final Map<String, String> markdown = <String, String>{};
  final Set<String> repoPaths = <String>{};
  _collect(Directory(repoRoot), '', markdown, repoPaths);

  final DocContext context = DocContext(
    docs: docs,
    tests: tests,
    markdown: markdown,
    repoPaths: repoPaths,
  );
  final List<DocIssue> issues = checkAll(context);
  final LinkScan links = scanLinks(context);

  final List<DocIssue> errors =
      issues.where((DocIssue i) => !i.isWarning).toList();
  final List<DocIssue> warnings =
      issues.where((DocIssue i) => i.isWarning).toList();

  for (final DocIssue i in <DocIssue>[...errors, ...warnings]) {
    stdout.writeln(i.toString());
  }
  stdout.writeln(
    '[docs] 检查 ${docs.length} 份交付物 · ${testFiles.length} 份测试文件 · '
    '${markdown.length} 份 Markdown（相对链接 ${links.checked} 条），'
    '${errors.length} 处违规 · ${warnings.length} 处警告',
  );
  exit(errors.isEmpty ? 0 : 1);
}

/// 递归收集 Markdown 与**全部**路径（文件 + 目录）。
///
/// 目录要进 [paths]：链接可以指向一个目录（`[参考层](reference/)`），只收文件
/// 会把这类合法写法判成坏链。
void _collect(
  Directory dir,
  String rel,
  Map<String, String> markdown,
  Set<String> paths,
) {
  final List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } on FileSystemException {
    return;
  }
  for (final FileSystemEntity e in entries) {
    final List<String> segs = e.uri.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList();
    if (segs.isEmpty) {
      continue;
    }
    final String name = segs.last;
    final String sub = rel.isEmpty ? name : '$rel/$name';
    if (e is Directory) {
      if (linkSkipDirs.contains(name)) {
        continue;
      }
      paths.add(sub);
      _collect(e, sub, markdown, paths);
      continue;
    }
    if (e is! File) {
      continue;
    }
    paths.add(sub);
    if (!name.endsWith('.md')) {
      continue;
    }
    try {
      markdown[sub] = e.readAsStringSync();
    } on FileSystemException {
      // 读不出来就当没有这份：`D6` 少查一份，不因一个坏文件崩掉整趟。
    }
  }
}
