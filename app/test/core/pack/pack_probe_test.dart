import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_probe.dart';

/// 内存文件系统：探测层只问三件事（是否文件 / 列子目录 / 读文本），
/// 足够用它替代磁盘 —— 也就把「路径拼接对不对」与「磁盘上有没有」解耦开。
class _MemoryFs implements PackFs {
  _MemoryFs({required this.files, this.unreadable = const <String>{}});

  final Map<String, String> files;
  final Set<String> unreadable;

  @override
  bool isFile(String path) => files.containsKey(path);

  @override
  List<String> listDirs(String path) {
    final Set<String> names = <String>{};
    for (final String file in files.keys) {
      if (file.startsWith('$path/')) {
        final String rest = file.substring(path.length + 1);
        final int cut = rest.indexOf('/');
        if (cut > 0) {
          names.add(rest.substring(0, cut));
        }
      }
    }
    return names.toList();
  }

  @override
  String? readString(String path) => unreadable.contains(path) ? null : files[path];
}

Map<String, String> _twoPacks() => <String, String>{
  'content/python/pack.json': '{}',
  'content/rust/pack.json': '{}',
};

void main() {
  group('路径探测', () {
    test('目录下有 pack.json 才算一个包（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(files: _twoPacks()),
      ).scanRoot('content', PackKind.payload);
      expect(result.problems, isEmpty);
      expect(
        result.locations.map((PackLocation l) => l.packRoot),
        <String>['content/python', 'content/rust'],
      );
      expect(result.locations.first.packPath, 'content/python/pack.json');
      expect(
        result.locations.every((PackLocation l) => l.kind == PackKind.payload),
        isTrue,
      );
    });

    test('目录里没有 pack.json ⇒ 报 missingPack，且不产出位置（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(
          files: <String, String>{
            // 旧形态：清单 + 产物两件，没有 `pack.json` —— 单文件形态下这就是坏包。
            'content/python/manifest.json': '{}',
            'content/python/dist/pack.json': '{}',
          },
        ),
      ).scanRoot('content', PackKind.payload);
      expect(result.locations, isEmpty);
      expect(result.problems.single.kind, PackProblemKind.missingPack);
      expect(result.problems.single.path, 'content/python/pack.json');
    });

    test('文件在但读不出来报 unreadable，不与「缺文件」混为一谈（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(
          files: _twoPacks(),
          unreadable: <String>{'content/rust/pack.json'},
        ),
      ).scanRoot('content', PackKind.payload);
      expect(result.locations.map((PackLocation l) => l.packRoot), <String>[
        'content/python',
      ]);
      expect(result.problems.single.kind, PackProblemKind.unreadable);
    });

    test('同一个 kind 内，候选根依次探测，同名目录以先出现的为准（SPEC-PACK-018）', () {
      final _MemoryFs fs = _MemoryFs(
        files: <String, String>{
          'dev/python/pack.json': '{}',
          'built/python/pack.json': '{}',
          'built/rust/pack.json': '{}',
        },
      );
      final ProbeResult result = PackProbe(fs).scanRoots(<PackKind, List<String>>{
        PackKind.payload: <String>['missing', 'dev', 'built'],
      });
      expect(result.locations.map((PackLocation l) => l.packRoot), <String>[
        'dev/python',
        'built/rust',
      ]);
    });

    test('根目录不存在 ⇒ 空结果且没有问题（无 SPEC：空根不是错误）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(files: <String, String>{}),
      ).scanRoot('nope', PackKind.payload);
      expect(result.isEmpty, isTrue);
      expect(result.problems, isEmpty);
    });

    test('同一包在两类候选根各探到一次，kind 各自正确（无 SPEC：kind 分组是 R-04 的回落机制，SPEC-PACK-018 尚未覆盖多 kind 探测）', () {
      final _MemoryFs fs = _MemoryFs(
        files: <String, String>{
          // `M2` 的形态：一个包既提供载荷又提供方法，可放两处副本。
          'payload-root/m2/pack.json': '{}',
          'method-root/m2/pack.json': '{}',
        },
      );
      final ProbeResult result = PackProbe(fs).scanRoots(<PackKind, List<String>>{
        PackKind.payload: <String>['payload-root'],
        PackKind.method: <String>['method-root'],
      });
      expect(result.locations.map((PackLocation l) => l.kind), <PackKind>[
        PackKind.payload,
        PackKind.method,
      ]);
      expect(result.locations.map((PackLocation l) => l.packRoot), <String>[
        'payload-root/m2',
        'method-root/m2',
      ]);
    });

    test('同一个根列给两个 kind ⇒ 两条位置、packRoot 相同（无 SPEC：kind 是查询维度而非存储位置）', () {
      final _MemoryFs fs = _MemoryFs(
        files: <String, String>{'content/m2/pack.json': '{}'},
      );
      final ProbeResult result = PackProbe(fs).scanRoots(<PackKind, List<String>>{
        PackKind.payload: <String>['content'],
        PackKind.method: <String>['content'],
      });
      // 这不是 bug：kind 是查询维度，权威的 `kinds[]` 由解析层读 `pack.json` 得出，
      // 装载层按 `packRoot` 合并。把它写成用例，是为了让「重复」这件事有据可查。
      expect(result.locations.length, 2);
      expect(result.locations.map((PackLocation l) => l.kind), <PackKind>[
        PackKind.payload,
        PackKind.method,
      ]);
      expect(
        result.locations.every((PackLocation l) => l.packRoot == 'content/m2'),
        isTrue,
      );
    });
  });
}
