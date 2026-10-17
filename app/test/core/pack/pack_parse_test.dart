import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/pack_parse.dart';

Map<String, Object?> _manifest({String id = 'python', String version = '0.1.0'}) =>
    <String, Object?>{
      'id': id,
      'name': 'Python 语法分层',
      'version': version,
      'sixAxis': <String, String>{'subject': '计算机科学'},
      'accent': '#3776ab',
      'order': 10,
      'domainIds': <String>['python/basics'],
    };

Map<String, Object?> _item(String id, {String title = '变量'}) => <String, Object?>{
  'id': id,
  'title': title,
  'sixAxis': <String, String>{'subject': '计算机科学', 'ability': '基础语法'},
  'layer': 'persistent',
  'type': 'declarative',
  'requirements': <String, Object?>{
    'boundary': 'present',
    'justification': 'present',
    'proposition': 'present',
    'relation': 'present',
    'how': 'present',
    'tacit': 'not_externalizable',
  },
  'sourceRefs': <String>[],
  'domainId': 'python/basics',
  'inScope': true,
};

Map<String, Object?> _pack({
  String space = 'python',
  String version = '0.1.0',
  List<Map<String, Object?>>? items,
  List<Map<String, Object?>>? edges,
  Map<String, Object?>? extra,
}) => <String, Object?>{
  'meta': <String, Object?>{'space': space, 'version': version},
  'items': items ?? <Map<String, Object?>>[_item('python/a')],
  'edges': edges ?? <Map<String, Object?>>[],
  'schemes': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'scheme-1',
      'name': '语法分层',
      'nodes': <String>['python/a'],
      'authorityLevel': 'L1',
    },
  ],
  'questions': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'q-1',
      'itemId': 'python/a',
      'prompt': '变量是什么？',
      'answer': '名字到对象的绑定',
    },
  ],
  'excerpts': <Map<String, Object?>>[],
  ...?extra,
};

LoadedPack _parse(Map<String, Object?> manifest, Map<String, Object?> pack) => parsePack(
  manifestJson: jsonEncode(manifest),
  packJson: jsonEncode(pack),
);

Matcher _throwsProblems([Object? contains]) => throwsA(
  isA<PackFormatException>().having(
    (PackFormatException e) => e.problems.join('\n'),
    'problems',
    contains == null ? anything : stringContainsInOrder(<String>['$contains']),
  ),
);

void main() {
  group('包解析', () {
    test('五段 + meta 齐备即可解析，并建好 id 索引（SPEC-PACK-005）', () {
      final LoadedPack pack = _parse(_manifest(), _pack());
      expect(pack.space.id, 'python');
      expect(pack.items.single.id, 'python/a');
      expect(pack.questions.single.itemId, 'python/a');
      expect(pack.itemOf('python/a')?.title, '变量');
      expect(pack.schemeNodes('scheme-1'), <String>['python/a']);
      expect(pack.schemeNodes('nope'), isNull);
    });

    test('meta.space 与清单 id 不一致即拒 —— 包与清单不是同一空间（SPEC-PACK-005）', () {
      expect(() => _parse(_manifest(id: 'rust'), _pack()), _throwsProblems('不是同一空间'));
    });

    test('meta.version 与清单 version 不一致即拒 —— 不是同一批产物（SPEC-PACK-005）', () {
      expect(() => _parse(_manifest(), _pack(version: '0.2.0')), _throwsProblems('不是同一批产物'));
    });

    test('多出 notes 段即拒 —— 笔记模板不进包（SPEC-PACK-007）', () {
      expect(
        () => _parse(_manifest(), _pack(extra: <String, Object?>{'notes': <Object?>[]})),
        _throwsProblems('不得出现 `notes` 段'),
      );
    });

    test('缺 items 段即拒，不补空数组（SPEC-PACK-005）', () {
      final Map<String, Object?> pack = _pack()..remove('items');
      expect(() => _parse(_manifest(), pack), _throwsProblems('缺 `items` 段'));
    });

    test('段内 id 重复即拒（SPEC-PACK-008）', () {
      expect(
        () => _parse(
          _manifest(),
          _pack(
            items: <Map<String, Object?>>[
              _item('python/a', title: '变量'),
              _item('python/a', title: '又一个变量'),
            ],
          ),
        ),
        _throwsProblems('`id` 重复'),
      );
    });

    test('有环的 ⪯ 即拒，并在报错里给出环路径（SPEC-FND-005）', () {
      expect(
        () => _parse(
          _manifest(),
          _pack(
            items: <Map<String, Object?>>[_item('python/a'), _item('python/b')],
            edges: <Map<String, Object?>>[
              <String, Object?>{'id': 'e1', 'from': 'python/a', 'to': 'python/b', 'type': 'strong'},
              <String, Object?>{'id': 'e2', 'from': 'python/b', 'to': 'python/a', 'type': 'strong'},
            ],
          ),
        ),
        _throwsProblems('出现环'),
      );
    });

    test('一次报全部问题，不是遇到第一个就停（无 SPEC：构建产物坏了通常坏一片）', () {
      final Map<String, Object?> pack = _pack(version: '9.9.9')
        ..remove('items')
        ..['stray'] = <Object?>[];
      try {
        _parse(_manifest(), pack);
        fail('应当抛出 PackFormatException');
      } on PackFormatException catch (error) {
        expect(error.problems.length, greaterThanOrEqualTo(3));
      }
    });

    test('坏 JSON 即拒并指名文件（无 SPEC：解码失败属通用契约）', () {
      expect(
        () => parsePack(manifestJson: '{', packJson: jsonEncode(_pack())),
        throwsA(isA<PackFormatException>()),
      );
    });
  });
}
