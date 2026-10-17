import 'package:flutter_test/flutter_test.dart';
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

Map<String, String> _twoSpaces() => <String, String>{
  'content/python/manifest.json': '{}',
  'content/python/dist/pack.json': '{}',
  'content/rust/manifest.json': '{}',
  'content/rust/dist/pack.json': '{}',
};

void main() {
  group('路径探测', () {
    test('清单与产物都在才算一个包（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(_MemoryFs(files: _twoSpaces())).scanRoot('content');
      expect(result.problems, isEmpty);
      expect(
        result.locations.map((PackLocation l) => l.spaceRoot),
        <String>['content/python', 'content/rust'],
      );
      expect(result.locations.first.packPath, 'content/python/dist/pack.json');
      expect(result.locations.first.manifestPath, 'content/python/manifest.json');
    });

    test('缺清单报 missingManifest，且不产出位置（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(
          files: <String, String>{
            'content/python/dist/pack.json': '{}',
          },
        ),
      ).scanRoot('content');
      expect(result.locations, isEmpty);
      expect(result.problems.single.kind, PackProblemKind.missingManifest);
      expect(result.problems.single.path, 'content/python/manifest.json');
    });

    test('清单在、产物不在报 missingPack —— 这是「忘了跑 build」的形状（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(files: <String, String>{'content/python/manifest.json': '{}'}),
      ).scanRoot('content');
      expect(result.locations, isEmpty);
      expect(result.problems.single.kind, PackProblemKind.missingPack);
      expect(result.problems.single.path, 'content/python/dist/pack.json');
    });

    test('文件在但读不出来报 unreadable，不与「缺文件」混为一谈（SPEC-PACK-018）', () {
      final ProbeResult result = PackProbe(
        _MemoryFs(
          files: _twoSpaces(),
          unreadable: <String>{'content/rust/dist/pack.json'},
        ),
      ).scanRoot('content');
      expect(result.locations.map((PackLocation l) => l.spaceRoot), <String>['content/python']);
      expect(result.problems.single.kind, PackProblemKind.unreadable);
    });

    test('候选根依次探测，同名空间以先出现的为准（SPEC-PACK-018）', () {
      final _MemoryFs fs = _MemoryFs(
        files: <String, String>{
          'dev/python/manifest.json': '{}',
          'dev/python/dist/pack.json': '{}',
          'built/python/manifest.json': '{}',
          'built/python/dist/pack.json': '{}',
          'built/rust/manifest.json': '{}',
          'built/rust/dist/pack.json': '{}',
        },
      );
      final ProbeResult result = PackProbe(fs).scanRoots(<String>['missing', 'dev', 'built']);
      expect(
        result.locations.map((PackLocation l) => l.spaceRoot),
        <String>['dev/python', 'built/rust'],
      );
    });

    test('根目录不存在 ⇒ 空结果且没有问题（无 SPEC：空根不是错误）', () {
      final ProbeResult result = PackProbe(_MemoryFs(files: <String, String>{})).scanRoot('nope');
      expect(result.isEmpty, isTrue);
      expect(result.problems, isEmpty);
    });
  });
}
