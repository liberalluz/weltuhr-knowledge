/// 文档换轨的迁移器：按批 `git mv` 搬文件，并把全仓相对链接按新布局**重算**。
///
/// 用法（在 `app/` 下）：
/// ```
/// dart run tool/docs/migrate_docs.dart --batch 2            # 预演，只打印，不动盘
/// dart run tool/docs/migrate_docs.dart --batch 2 --apply    # 真跑：git mv + 改链接
/// dart run tool/docs/migrate_docs.dart                      # 不带批号：打印用法与各批份数
/// ```
///
/// ## 为什么是「重算」而不是「替换」
///
/// 字符串前缀替换（`docs/reference/` → `docs/specs/`）有两类必然漏改：
/// 1. **深层链接**指向具体文件，而新位置不保留原目录结构（`reference/` 拆成四个目录）；
/// 2. **跨目录的 `../` 相对路径**在文件自身搬家后深度会变 ——
///    `docs/readme/README.zh.md` 搬到仓根后，原来写 `../../LICENSE` 的必须变成 `LICENSE`。
///    这类改写与「目标搬没搬」无关，是**链接所在文件搬了**导致的。
///
/// 本器的做法是：把每条链接解析成仓库相对路径 → 在映射表里查目标的新位置 →
/// 从「链接所在文件的新位置」反算相对路径。结果与起点无关，也不会漏第 2 类。
///
/// ## 与 `check.dart` 的关系
///
/// 用同一份 [`markdown_links.dart`](markdown_links.dart) 解析，口径不会漂。
/// 每批 `--apply` 之后必须跑 `dart run tool/docs/check.dart`，`D6` 是唯一兜底 ——
/// 本器只保证「算得对」，不保证「映射表全对」。
///
/// ## 三类产出
///
/// - `MOVES`：搬哪些文件（`--apply` 时执行 `git mv`，保留历史）
/// - `REWRITE`：能自动算的链接改写
/// - `MANUAL`：搬完之后**必然断链**的条目（多为目录级链接，如 `[guides/](guides/)`）——
///   映射表无法把「一个目录」映到「四个目录」，只能人工就地改
library;

import 'dart:io';

import 'markdown_links.dart';

/// 批号 → {旧仓相对路径: 新仓相对路径}。
///
/// 批 0 与批 6 **不搬文件**，故不在表内。批 1 已完成（规范定稿，不涉目录）。
/// 全量 65 份的逐份依据见 ADR-0008 与批 0 的映射表。
const Map<int, Map<String, String>> batches = <int, Map<String, String>>{
  2: <String, String>{
    'docs/adr/0001-project-baseline.md':
        'docs/decisions/0001-project-baseline.md',
    'docs/adr/0002-dev-order-vertical-slice.md':
        'docs/decisions/0002-dev-order-vertical-slice.md',
    'docs/adr/0003-view-radial-axis-and-channel-thresholds.md':
        'docs/decisions/0003-view-radial-axis-and-channel-thresholds.md',
    'docs/adr/0004-accounts-as-usage-prerequisite.md':
        'docs/decisions/0004-accounts-as-usage-prerequisite.md',
    'docs/adr/0005-three-axis-tree-replaces-six-axis.md':
        'docs/decisions/0005-three-axis-tree-replaces-six-axis.md',
    'docs/adr/0006-3d-rendering-stack-and-visual-style.md':
        'docs/decisions/0006-3d-rendering-stack-and-visual-style.md',
    'docs/adr/0007-node-type-shape.md':
        'docs/decisions/0007-node-type-shape.md',
    // 本 ADR 自己也在这批搬 —— 批 0 写它时 `decisions/` 还不存在，
    // 只能先落 `adr/`，于是它成为批 2 的第 9 份。
    'docs/adr/0008-five-dir-docs-taxonomy.md':
        'docs/decisions/0008-five-dir-docs-taxonomy.md',
    'docs/adr/README.md': 'docs/decisions/README.md',
  },
  3: <String, String>{
    'docs/design/00-index.md': 'docs/specs/00-index.md',
    'docs/design/ACC-accounts.md': 'docs/specs/ACC-accounts.md',
    'docs/design/FND-foundation.md': 'docs/specs/FND-foundation.md',
    'docs/design/GOV-governance.md': 'docs/specs/GOV-governance.md',
    'docs/design/NOTE-notes.md': 'docs/specs/NOTE-notes.md',
    'docs/design/PACK-content-pack.md': 'docs/specs/PACK-content-pack.md',
    'docs/design/PLAN-planning.md': 'docs/specs/PLAN-planning.md',
    'docs/design/QUANT-quantification.md': 'docs/specs/QUANT-quantification.md',
    'docs/design/STEP-learning-steps.md': 'docs/specs/STEP-learning-steps.md',
    'docs/design/SYNC-sync.md': 'docs/specs/SYNC-sync.md',
    'docs/design/VIEW-views.md': 'docs/specs/VIEW-views.md',
  },
  4: <String, String>{
    // 8 份规格：横切表与验收样本
    'docs/reference/channel-table.md': 'docs/specs/channel-table.md',
    'docs/reference/constants.md': 'docs/specs/constants.md',
    'docs/reference/entity-fields.md': 'docs/specs/entity-fields.md',
    'docs/reference/event-types.md': 'docs/specs/event-types.md',
    'docs/reference/glossary.md': 'docs/specs/glossary.md',
    'docs/reference/minimal-pack.md': 'docs/specs/minimal-pack.md',
    'docs/reference/path-rules.md': 'docs/specs/path-rules.md',
    'docs/reference/skeleton-catalog.md': 'docs/specs/skeleton-catalog.md',
    // 2 份决策台账：同一根轴的两端
    'docs/reference/not-list.md': 'docs/decisions/not-list.md',
    'docs/reference/open-decisions.md': 'docs/decisions/open-decisions.md',
    // 2 份论证：论证与依据，不随实现改动
    'docs/reference/knowledge-space-navigation-methodology.md':
        'docs/intent/knowledge-space-navigation-methodology.md',
    'docs/reference/knowledge-system-learning-methodology.md':
        'docs/intent/knowledge-system-learning-methodology.md',
  },
  5: <String, String>{
    // 2 份是规范，不是操作
    'docs/guides/git-conventions.md': 'docs/specs/git-conventions.md',
    'docs/guides/dependency-licenses.md':
        'docs/specs/dependency-licenses.md',
    // 1 份才是操作
    'docs/guides/environment.md': 'docs/runbooks/environment.md',
    // 5 份 README 语言副本移到仓根（docsLocale.scheme = suffix）
    'docs/readme/README.zh.md': 'README.zh.md',
    'docs/readme/README.de.md': 'README.de.md',
    'docs/readme/README.fr.md': 'README.fr.md',
    'docs/readme/README.it.md': 'README.it.md',
    'docs/readme/README.ja.md': 'README.ja.md',
  },
};

/// 遍历时整棵跳过的目录 —— 与 [`check.dart`](check.dart) 的 `linkSkipDirs` 一致。
const Set<String> skipDirs = <String>{
  '.git',
  '.dart_tool',
  '.idea',
  'build',
  'node_modules',
  'tmp',
};

/// 一条待改写的链接。
class Rewrite {
  const Rewrite({
    required this.file,
    required this.line,
    required this.before,
    required this.after,
  });

  final String file;
  final int line;
  final String before;
  final String after;
}

/// 一条搬完后必然断链、只能人工处理的链接。
class Manual {
  const Manual({
    required this.file,
    required this.line,
    required this.raw,
    required this.resolvedOld,
    required this.why,
  });

  final String file;
  final int line;
  final String raw;
  final String resolvedOld;
  final String why;
}

void main(List<String> args) {
  // `--batch 2` 里的 `2` 不以 `-` 开头，若只按前缀过滤会被当成仓库根 ——
  // 必须先把 `--batch` 的值吃掉，再看剩下谁是位置参数。
  final List<String> positional = <String>[];
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--batch') {
      i++;
      continue;
    }
    if (args[i].startsWith('-')) {
      continue;
    }
    positional.add(args[i]);
  }
  final String repoRoot = positional.isEmpty ? '..' : positional.first;

  final int? batch = _intFlag(args, '--batch');
  final bool apply = args.contains('--apply');

  if (batch == null) {
    stdout.writeln('文档换轨迁移器 —— 用法：');
    stdout.writeln('  --batch <N>            预演第 N 批（只打印，不动盘）');
    stdout.writeln('  --batch <N> --diff     预演并逐条打印 旧 -> 新');
    stdout.writeln('  --batch <N> --apply    执行第 N 批（git mv + 改链接）');
    stdout.writeln('  [仓库根]               默认 `..`（在 app/ 下执行）');
    stdout.writeln('');
    stdout.writeln('各批份数：');
    final List<int> keys = batches.keys.toList()..sort();
    for (final int k in keys) {
      stdout.writeln('  批 $k：${batches[k]!.length} 份');
    }
    final int total =
        batches.values.fold(0, (int s, Map<String, String> m) => s + m.length);
    stdout.writeln('  合计：$total 份');
    final Set<String> uniq = <String>{
      for (final Map<String, String> m in batches.values) ...m.keys,
    };
    if (uniq.length != total) {
      stderr.writeln('[migrate] 映射表有重复的旧路径：$total 条 vs 去重 ${uniq.length}');
      exit(2);
    }
    return;
  }

  final Map<String, String> moves = batches[batch]!;
  final FileSystemEntityType rootType =
      FileSystemEntity.typeSync(repoRoot);
  if (rootType != FileSystemEntityType.directory) {
    stderr.writeln('[migrate] 仓库根不存在：$repoRoot（请在 app/ 下执行）');
    exit(2);
  }

  // 1) 收集旧布局：全部 Markdown 的原内容 + 文件与目录两类路径。
  final Map<String, String> markdown = <String, String>{};
  final Set<String> oldFiles = <String>{};
  final Set<String> oldDirs = <String>{};
  _collect(Directory(repoRoot), '', markdown, oldFiles, oldDirs);

  // 2) 推算新布局的路径集合。
  //
  // ⚠️ 目录不能直接沿用「旧布局里它在」这个事实：git 不跟踪空目录，
  // 一个目录下的文件全被搬走就等于该目录消失。旧的写法把目录原样带过来，
  // 于是 `[adr/](adr/)` 这类目录级链接从不报 MANUAL —— 预演全绿、真搬到一半才断。
  final Set<String> newFileSet = <String>{...oldFiles}
    ..removeAll(moves.keys)
    ..addAll(moves.values);
  final Set<String> newPaths = <String>{...newFileSet};
  for (final String d in oldDirs) {
    final bool stillHasChild =
        newFileSet.any((String f) => f.startsWith('$d/'));
    if (stillHasChild) {
      newPaths.add(d);
    }
  }
  // 搬出来的新目录（`docs/decisions/` 等）未必在旧目录表里，补上。
  for (final String target in moves.values) {
    final List<String> segs = target.split('/');
    for (int i = 1; i < segs.length; i++) {
      newPaths.add(segs.take(i).join('/'));
    }
  }

  // 3) 逐文件算链接改写。
  final List<Rewrite> rewrites = <Rewrite>[];
  final List<Manual> manuals = <Manual>[];
  final List<String> files = markdown.keys.toList()..sort();
  for (final String file in files) {
    final String newFile = moves[file] ?? file;
    final List<String> lines = markdown[file]!.split('\n');
    bool inFence = false;
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      if (fenceRe.hasMatch(line)) {
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        continue;
      }
      final List<(int, int)> codeSpans = <(int, int)>[
        for (final RegExpMatch m in inlineCodeRe.allMatches(line))
          (m.start, m.end),
      ];
      for (final RegExpMatch m in linkRe.allMatches(line)) {
        if (codeSpans.any(((int, int) s) => m.start >= s.$1 && m.start < s.$2)) {
          continue;
        }
        final String raw = m.group(1)!;
        if (isExternalTarget(raw)) {
          continue;
        }
        final String pathPart = raw.split('#').first;
        if (pathPart.isEmpty || pathPart.startsWith('/')) {
          continue;
        }
        final String anchor = raw.substring(pathPart.length);

        // 用**旧位置**解析：链接写的是旧布局。
        final String? oldAbs = resolveLink(file, pathPart);
        if (oldAbs == null) {
          manuals.add(
            Manual(
              file: file,
              line: i + 1,
              raw: raw,
              resolvedOld: '（越出仓库根）',
              why: '相对链接上跳越过仓库根，本器不猜意图',
            ),
          );
          continue;
        }

        final String newAbs = moves[oldAbs] ?? oldAbs;

        // 搬完之后目标还在不在：既不在新路径集合，说明它随本批消失。
        if (!newPaths.contains(newAbs)) {
          manuals.add(
            Manual(
              file: file,
              line: i + 1,
              raw: raw,
              resolvedOld: oldAbs,
              why: '本批执行后 `$newAbs` 不存在（目录级链接或已被搬空的旧目录）',
            ),
          );
          continue;
        }

        // 链接两端（所在文件、目标）都没动 ⇒ **一个字都不改**。
        //
        // 这条守卫是必需的：不加的话本器会把 `../../docs/README.md` 规范成
        // `../README.md`（两者等价，但前者绕了路）。批 2 只搬 `adr/`，却去改
        // `readme/` 里 30 条无关链接 —— diff 噪音会淹没真正的改动，评审无法分辨
        // 「搬家的必要改动」和「顺手规范化」。
        if (newFile == file && newAbs == oldAbs) {
          continue;
        }

        String newTarget = relativeLink(newAbs, newFile);
        if (pathPart.endsWith('/') && !newTarget.endsWith('/')) {
          newTarget += '/';
        }
        final String newRaw = '$newTarget$anchor';
        if (newRaw != raw) {
          rewrites.add(
            Rewrite(file: file, line: i + 1, before: raw, after: newRaw),
          );
        }
      }
    }
  }

  // 4) 报告。
  stdout.writeln('[migrate] 批 $batch · ${apply ? "执行" : "预演"} · 仓库根 `$repoRoot`');
  stdout.writeln('');
  stdout.writeln('== MOVES（${moves.length} 份）==');
  final List<String> oldMoved = moves.keys.toList()..sort();
  for (final String old in oldMoved) {
    final String? newPath = moves[old];
    final bool fromExists = File('$repoRoot/$old').existsSync();
    stdout.writeln('  $old');
    stdout.writeln('    -> $newPath${fromExists ? "" : "   [源文件不存在]"}${
        File('$repoRoot/${newPath!}').existsSync() ? "   [目标已存在]" : ""}');
  }

  stdout.writeln('');
  stdout.writeln('== REWRITE（${rewrites.length} 条）==');
  final Map<String, int> perFile = <String, int>{};
  for (final Rewrite r in rewrites) {
    perFile[r.file] = (perFile[r.file] ?? 0) + 1;
  }
  final List<String> rewriteFiles = perFile.keys.toList()..sort();
  for (final String f in rewriteFiles) {
    stdout.writeln('  $f   ${perFile[f]} 条');
  }
  if (args.contains('--diff')) {
    stdout.writeln('');
    stdout.writeln('--- 逐条明细 ---');
    for (final Rewrite r in rewrites) {
      stdout.writeln('  ${r.file}:${r.line}');
      stdout.writeln('    - ${r.before}');
      stdout.writeln('    + ${r.after}');
    }
  }

  stdout.writeln('');
  stdout.writeln('== MANUAL（${manuals.length} 条，必须人工改，否则 main 断链）==');
  for (final Manual m in manuals) {
    final String newFile = moves[m.file] ?? m.file;
    stdout.writeln('  $newFile:${m.line}  `${m.raw}`');
    stdout.writeln('    旧解析 -> ${m.resolvedOld}');
    stdout.writeln('    原因：${m.why}');
  }

  if (!apply) {
    stdout.writeln('');
    stdout.writeln('[migrate] 预演结束，未动盘。加 --apply 执行。');
    return;
  }

  // 5) 执行：git mv（保留历史）→ 按新路径写回链接。
  stdout.writeln('');
  stdout.writeln('== 执行 ==');
  for (final String old in oldMoved) {
    final String newPath = moves[old]!;
    final int slash = newPath.lastIndexOf('/');
    if (slash > 0) {
      Directory('$repoRoot/${newPath.substring(0, slash)}')
          .createSync(recursive: true);
    }
    final ProcessResult r = Process.runSync(
      'git',
      <String>['mv', old, newPath],
      workingDirectory: repoRoot,
    );
    if (r.exitCode != 0) {
      stderr.writeln('[migrate] git mv 失败：$old -> $newPath');
      stderr.writeln('${r.stderr}');
      exit(1);
    }
    stdout.writeln('  mv $old -> $newPath');
  }

  // 按行号分组，一次性重建文件，避免多次读写。
  final Map<String, Map<int, List<Rewrite>>> byFile =
      <String, Map<int, List<Rewrite>>>{};
  for (final Rewrite r in rewrites) {
    (byFile[r.file] ??= <int, List<Rewrite>>{})
        .putIfAbsent(r.line, () => <Rewrite>[])
        .add(r);
  }
  int written = 0;
  for (final String oldFile in byFile.keys.toList()..sort()) {
    final String newFile = moves[oldFile] ?? oldFile;
    final List<String> lines = markdown[oldFile]!.split('\n');
    for (final int lineNo in byFile[oldFile]!.keys) {
      final String line = lines[lineNo - 1];
      final List<Rewrite> items = byFile[oldFile]![lineNo]!;
      lines[lineNo - 1] = _applyOneLine(line, items);
    }
    File('$repoRoot/$newFile').writeAsStringSync(lines.join('\n'));
    written++;
  }
  stdout.writeln('  改写 $written 个文件');
  if (manuals.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('[migrate] 注意：还有 ${manuals.length} 条 MANUAL 未处理，'
        '现在跑 check.dart 会红。');
  }
}

/// 把一行里若干条链接换成新写法。
///
/// 从左到右按 `](` 之后的目标区间定位，用游标拼接 —— 不用 `replaceAll`：
/// 同一行可能出现同一个旧目标两次，替换会连锁（第二次匹配到已改过的文本）。
String _applyOneLine(String line, List<Rewrite> items) {
  final StringBuffer buf = StringBuffer();
  int last = 0;
  int idx = 0;
  for (final RegExpMatch m in linkRe.allMatches(line)) {
    if (idx >= items.length) {
      break;
    }
    if (m.group(1) != items[idx].before) {
      continue;
    }
    // `Match` 没有「第 N 组在行内的区间」这种访问器（`start` / `end` 是整段匹配的
    // 属性，不是方法），所以在整段匹配里找目标串的偏移，再换算回行内位置。
    // 整段匹配以 `](` 开头、目标串不含 `)` 与空白，故 `indexOf` 不会错配。
    final String whole = m.group(0)!;
    final int targetStart = m.start + whole.indexOf(items[idx].before);
    final int targetEnd = targetStart + items[idx].before.length;
    buf.write(line.substring(last, targetStart));
    buf.write(items[idx].after);
    last = targetEnd;
    idx++;
  }
  buf.write(line.substring(last));
  return buf.toString();
}

/// 递归收集 Markdown 内容、文件路径与目录路径，跳过 [skipDirs]。
void _collect(
  Directory dir,
  String prefix,
  Map<String, String> markdown,
  Set<String> files,
  Set<String> dirs,
) {
  final List<FileSystemEntity> entries = dir.listSync()
    ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));
  for (final FileSystemEntity e in entries) {
    final String name = e.uri.pathSegments.lastWhere((String s) => s.isNotEmpty);
    final String rel = prefix.isEmpty ? name : '$prefix/$name';
    if (e is Directory) {
      if (skipDirs.contains(name)) {
        continue;
      }
      dirs.add(rel);
      _collect(e, rel, markdown, files, dirs);
      continue;
    }
    if (e is File) {
      files.add(rel);
      if (name.endsWith('.md')) {
        markdown[rel] = e.readAsStringSync();
      }
    }
  }
}

int? _intFlag(List<String> args, String name) {
  final int i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) {
    return null;
  }
  return int.tryParse(args[i + 1]);
}
