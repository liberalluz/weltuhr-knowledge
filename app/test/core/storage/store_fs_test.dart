import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/pack/dart_io_pack_fs.dart';
import 'package:project_knowledge/core/storage/store_fs.dart';

/// 存储三区接缝的**真实磁盘**回归（`entity-fields.md` §〇 · `B13a` 笔 3）。
///
/// 为什么不用内存实现：这里要验的语义就是「写到一半挂了会怎样」，而内存实现里
/// 「写一半」不存在 —— 拿它验原子性等于把要验的那条语义 mock 掉，全绿也没有
/// 证明力。所以全部用例打到 `Directory.systemTemp` 下的真实目录。
void main() {
  late Directory root;
  late String base;
  late DartIoPackFs fs;

  setUp(() {
    root = Directory.systemTemp.createTempSync('weltuhr_store_');
    base = root.path;
    fs = const DartIoPackFs();
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// 目录里的全部文件名（不含路径）。用来断言「临时文件没残留」。
  List<String> names(String path) {
    final Directory dir = Directory(path);
    if (!dir.existsSync()) {
      return const <String>[];
    }
    return dir
        .listSync()
        .map((FileSystemEntity e) => e.uri.pathSegments.where((String s) => s.isNotEmpty).last)
        .toList()
      ..sort();
  }

  group('可写内容区 · 原子写', () {
    test('写新文件：内容落盘，且临时文件不残留（ADR-0005 决策 5）', () {
      final String path = '$base/claims.json';

      final bool ok = fs.writeStringAtomic(path, '{"a":1}');

      expect(ok, isTrue);
      expect(fs.readString(path), '{"a":1}');
      expect(names(root.path), <String>['claims.json'], reason: '.tmp 残留会一直堆在用户目录里');
    });

    test('覆盖已有文件：内容换成新的，旧内容不残留（ADR-0005 决策 5）', () {
      final String path = '$base/claims.json';
      expect(fs.writeStringAtomic(path, 'old'), isTrue);

      expect(fs.writeStringAtomic(path, 'new'), isTrue);

      expect(fs.readString(path), 'new');
      expect(names(root.path), <String>['claims.json']);
    });

    test('写不下去时返回 false 且**不动旧内容** —— 半截写入比写失败更糟（ADR-0005 决策 5）', () {
      // 目标路径是个**目录**：rename 必然失败。要点是「失败之后旧内容还在」，
      // 而不是「失败之后文件被清空了」。
      final String dir = '$base/occupied';
      expect(fs.ensureDir(dir), isTrue);
      final String keeper = '$dir/keep.json';
      expect(fs.writeStringAtomic(keeper, 'keep'), isTrue);

      final bool ok = fs.writeStringAtomic(dir, 'clobber');

      expect(ok, isFalse);
      expect(fs.readString(keeper), 'keep', reason: '一次失败的写不能波及同目录的其它事实');
      expect(names(dir), <String>['keep.json']);
      // 临时文件建在**目标路径旁**（同目录才保证 rename 原子），目标是目录时
      // 它落在目标的上一级 —— 所以要查上一级，不是查 `dir` 里面。
      // 这条最初写成 `names(dir)`，而临时文件根本不在 `dir` 里：撤掉清理逻辑
      // 它照样绿（反证当场抓住）。判据写错了位置，等于没判。
      expect(
        names(root.path),
        <String>['occupied'],
        reason: '失败必须清掉自己的临时文件，否则用户目录会一直堆 .tmp',
      );
    });

    test('目标目录不存在时不自行建目录 —— 建目录是调用方的显式动作（无 SPEC：接口分工）', () {
      final String path = '$base/missing/x.json';

      expect(fs.writeStringAtomic(path, 'v'), isFalse);
    });

    test('目录建好之后同一路径即可写（无 SPEC：建目录与写是两个显式动作）', () {
      final String dir = '$base/a/b/c';
      expect(fs.ensureDir(dir), isTrue);
      expect(fs.writeStringAtomic('$dir/x.json', 'v'), isTrue);
      expect(fs.readString('$dir/x.json'), 'v');
    });
  });

  group('事件日志区 · 追加', () {
    test('连续追加两行，行间只有一个换行（ADR-0005 决策 5）', () {
      final String path = '$base/events.jsonl';

      expect(fs.appendLine(path, '{"n":1}'), isTrue);
      expect(fs.appendLine(path, '{"n":2}'), isTrue);

      expect(fs.readString(path), '{"n":1}$eventLogLineBreak{"n":2}$eventLogLineBreak');
    });

    test('已带行尾换行的输入不重复补（无 SPEC：避免空行）', () {
      final String path = '$base/events.jsonl';

      expect(fs.appendLine(path, 'line$eventLogLineBreak'), isTrue);

      expect(fs.readString(path), 'line$eventLogLineBreak');
    });

    test('目录不存在时返回 false —— 半行写入比写不进去更难查（无 SPEC：接口分工）', () {
      expect(fs.appendLine('$base/nope/events.jsonl', 'x'), isFalse);
    });

    test('追加不改动已有内容 —— 事件日志只能变长（SPEC-FND-012）', () {
      final String path = '$base/events.jsonl';
      // 第一条显式带换行：这样本用例只锁「旧内容不变」，不依赖「补换行」那条
      // 实现细节 —— 否则撤掉补换行会同时红两条，归因就说不清了。
      expect(fs.appendLine(path, 'a$eventLogLineBreak'), isTrue);

      expect(fs.appendLine(path, 'b'), isTrue);

      expect(fs.readString(path)!.startsWith('a$eventLogLineBreak'), isTrue);
    });
  });

  group('读能力', () {
    test('非 UTF-8 返回 null 而不是猜编码（无 SPEC：坏包不猜编码）', () {
      final String path = '$base/bad.json';
      File(path).writeAsBytesSync(<int>[0xFF, 0xFE, 0x00]);

      expect(fs.readString(path), isNull);
    });

    test('不存在的文件读为 null、isFile 为 false（无 SPEC：读接口一律总函数）', () {
      final String path = '$base/none.json';

      expect(fs.readString(path), isNull);
      expect(fs.isFile(path), isFalse);
    });
  });

  group('三区接缝的类型关系', () {
    test('同一个实现类同时满足三个区的能力（无 SPEC：三区共用一份实现）', () {
      // 这不是「一个实例可以随便越区」：越界由 StoreLayout 判。本用例只锁
      // 「三区能力都有实现，不必为每个区再造一个类」。
      expect(fs, isA<StoreFs>());
      expect(fs, isA<WritableStoreFs>());
      expect(fs, isA<AppendOnlyStoreFs>());
    });
  });
}
