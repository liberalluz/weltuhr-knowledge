import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/constants.dart';
import 'package:project_knowledge/core/json.dart';
import 'package:project_knowledge/core/pack/triple_validator.dart';

/// M1 夹具根目录。测试的工作目录是 `app/`（`flutter test` 的约定）。
const String _root = 'test/fixtures/m1';

Map<String, Object?> _readJson(String path) {
  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  return (decoded as Map<Object?, Object?>).map(
    (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
  );
}

/// 反例子目录，按名排序 —— 顺序固定才能让失败信息稳定可读。
List<Directory> _negativeDirs() {
  final List<Directory> dirs = Directory(_root).listSync().whereType<Directory>().toList()
    ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
  return dirs;
}

String _dirName(Directory dir) => dir.path.split(RegExp(r'[\\/]')).last;

void main() {
  group('三元校验 · 正例', () {
    test('3 节点 / 4 边 / 2 entry 全绿，且 path 与期望映射逐条相等（ADR-0005 决策 7）', () {
      final Map<String, Object?> pack = _readJson('$_root/pack.json');
      final Map<String, Object?> expected = _readJson('$_root/expect.json');
      final Map<String, String> skeletonPaths = requireStringMap(expected, 'skeletonPaths');

      final PathValidation result = validatePack(pack, skeletonPaths);

      expect(result.codes, isEmpty, reason: '正例必须无码，实际 ${result.codes}');
      expect(result.paths, requireStringMap(expected, 'paths'));
    });

    test('path 由父链重算，不来自任何缓存或字段（ADR-0007 决策 2 · R9）', () {
      final Map<String, Object?> pack = _readJson('$_root/pack.json');
      final Map<String, String> skeletonPaths = requireStringMap(
        _readJson('$_root/expect.json'),
        'skeletonPaths',
      );

      // 包里没有任何节点带 `path` 字段 —— 派生值不入库。
      for (final JsonMap node in requireMapList(pack, 'nodes')) {
        expect(node.containsKey('path'), isFalse, reason: '`path` 不得作为字段出现（P-01）');
      }

      final PathValidation result = validatePack(pack, skeletonPaths);
      // 三级路径逐段可验：恒星槽位（注入）→ system → planet。
      expect(result.paths['m1-demo:cs-core'], 'major/08/0809/080901/cs-core');
      expect(result.paths['m1-demo:var'], 'major/08/0809/080901/cs-core/var');
      expect(result.paths['m1-demo:func'], 'major/08/0809/080901/cs-core/func');
    });

    test('骨架 path 由调用方注入：换一份注入表则 path 跟着换，接口不变（ADR-0005 决策 7）', () {
      final Map<String, Object?> pack = _readJson('$_root/pack.json');
      const Map<String, String> alternate = <String, String>{
        'skeleton:major/080901': 'major/99/9999/999999',
      };

      final PathValidation result = validatePack(pack, alternate);

      expect(result.ok, isTrue);
      expect(result.paths['m1-demo:cs-core'], 'major/99/9999/999999/cs-core');
    });

    test('父节点缺失时无码可报会静默通过 —— 校验器必须拒绝（ADR-0005 决策 7）', () {
      final Map<String, Object?> pack = _readJson('$_root/pack.json');
      // 不给骨架注入表：`cs-core` 的父链断在半路。
      final PathValidation result = validatePack(pack, const <String, String>{});

      expect(result.codes, <String>[codePathParent]);
      expect(result.paths, isEmpty, reason: '失败时不给半份 path 表');
    });
  });

  group('三元校验 · 反例（每个只差一处，只期望一个码）', () {
    for (final Directory dir in _negativeDirs()) {
      final String name = _dirName(dir);
      final Map<String, Object?> expected = _readJson('${dir.path}/expect.json');
      final List<String> expectedCodes = requireStringList(expected, 'codes');

      test('$name 恰好报 ${expectedCodes.join()}（ADR-0005 决策 7 · 顺序固定才可归因）', () {
        final Map<String, Object?> pack = _readJson('${dir.path}/pack.json');
        // 反例不带 `skeletonPaths`：它继承正例基线（`expect.json` 的 `base` 字段）。
        final Map<String, String> skeletonPaths = requireStringMap(
          _readJson('$_root/expect.json'),
          'skeletonPaths',
        );

        final PathValidation result = validatePack(pack, skeletonPaths);

        expect(result.codes, expectedCodes);
        expect(result.codes, hasLength(1), reason: 'fail-fast 下只允许一个码');
        expect(result.ok, isFalse);
        expect(result.paths, isEmpty);
      });
    }
  });

  group('slug 字符集（P-04）', () {
    test('下划线只允许作为保留段前缀，且保留段不由作者使用（ADR-0005 决策 7）', () {
      expect(slugPattern.hasMatch('cs-core'), isTrue);
      expect(slugPattern.hasMatch('a1'), isTrue);
      expect(slugPattern.hasMatch('_extra'), isFalse, reason: '`_` 不在字符集内');
      expect(slugPattern.hasMatch('Func'), isFalse);
      expect(slugPattern.hasMatch('func_2'), isFalse);
      expect(reservedSegmentPrefix, '_');
    });
  });
}
