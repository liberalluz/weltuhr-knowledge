import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/overlay_patch.dart';
import 'package:project_knowledge/core/enums.dart';

void main() {
  group('OverlayPatch（无 SPEC：entity-fields §8）', () {
    test('字段级补丁逐项落地（无 SPEC：§8 定字段集）', () {
      final OverlayPatch patch = OverlayPatch.fromJson(<String, Object?>{
        'scope': 'S2',
        'target_id': 'm2-demo:var',
        'field': 'summary',
        'value': '机构改写的一句话',
        'base_hash': 'sha256:abc',
        'state': 'applied',
      });
      expect(patch.scope, Scope.s2);
      expect(patch.targetId, 'm2-demo:var');
      expect(patch.field, 'summary');
      expect(patch.value, '机构改写的一句话');
      expect(patch.baseHash, 'sha256:abc');
      expect(patch.isStale, isFalse);
    });

    test('value 不收窄类型：数组与对象原样携带（无 SPEC：§8 写「any」）', () {
      final OverlayPatch patch = OverlayPatch.fromJson(<String, Object?>{
        'scope': 'S4',
        'target_id': 'm2-demo:var',
        'field': 'outcomes',
        'value': <String>['能说明重新绑定', '能区分名字与对象'],
        'base_hash': 'sha256:def',
        'state': 'stale',
      });
      expect(patch.value, isA<List<Object?>>());
      expect((patch.value! as List<Object?>).length, 2);
    });

    test('指纹失配 ⇒ stale，且不自动应用（无 SPEC：entity-fields §8 注）', () {
      final OverlayPatch patch = OverlayPatch.fromJson(<String, Object?>{
        'scope': 'S3',
        'target_id': 'n',
        'field': 'summary',
        'value': 'x',
        'base_hash': '',
        'state': 'stale',
      });
      expect(patch.state, PatchState.stale);
      expect(patch.isStale, isTrue);
    });

    test('value 允许为 null —— 补丁可以「清空一格」（无 SPEC：§8 未排除 null）', () {
      final OverlayPatch patch = OverlayPatch.fromJson(<String, Object?>{
        'scope': 'S4',
        'target_id': 'n',
        'field': 'summary',
        'value': null,
        'base_hash': 'sha256:0',
        'state': 'applied',
      });
      expect(patch.value, isNull);
      expect(patch.toJson()['value'], isNull);
    });
  });
}
