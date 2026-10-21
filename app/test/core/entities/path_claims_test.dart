import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/path_claims.dart';
import 'package:project_knowledge/core/enums.dart';

void main() {
  group('PathClaim（无 SPEC：entity-fields §6）', () {
    test('占用与墓碑两态（无 SPEC：§6 定字段集）', () {
      final PathClaim live = PathClaim.fromJson(<String, Object?>{
        'path': 'major/080901/lang-core/var',
        'node_id': 'm2-demo:var',
        'state': 'live',
      });
      expect(live.path, 'major/080901/lang-core/var');
      expect(live.nodeId, 'm2-demo:var');
      expect(live.isTombstone, isFalse);

      final PathClaim tomb = PathClaim.fromJson(<String, Object?>{
        'path': 'major/080901/lang-core/var',
        'node_id': 'm2-demo:var',
        'state': 'tombstone',
      });
      expect(tomb.isTombstone, isTrue);
    });

    test('未知 state 不在册即报，允许值一并列出（无 SPEC：枚举口径）', () {
      expect(
        () => PathClaim.fromJson(<String, Object?>{
          'path': 'p',
          'node_id': 'n',
          'state': 'deleted',
        }),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('tombstone'),
          ),
        ),
      );
    });
  });

  group('PathAlias（无 SPEC：entity-fields §7）', () {
    test('parent_change 必须带版本区间（无 SPEC：§7「仅 parentChange 必填」）', () {
      final PathAlias withRange = PathAlias.fromJson(<String, Object?>{
        'old_path': 'major/080901/lang-core/var',
        'node_id': 'm2-demo:variable',
        'reason': 'parent_change',
        'from_ver': '1.0.0',
        'to_ver': '2.0.0',
      });
      expect(withRange.reason, PathAliasReason.parentChange);
      expect(withRange.hasVersionRange, isTrue);

      final PathAlias withoutRange = PathAlias.fromJson(<String, Object?>{
        'old_path': 'major/080901/lang-core/var',
        'node_id': 'm2-demo:variable',
        'reason': 'parent_change',
      });
      expect(withoutRange.hasVersionRange, isFalse);
    });

    test('slug_change 的版本区间允许为空（无 SPEC：§7「发生在骨架版本轴之外」）', () {
      final PathAlias alias = PathAlias.fromJson(<String, Object?>{
        'old_path': 'major/080901/lang-core/vars',
        'node_id': 'm2-demo:var',
        'reason': 'slug_change',
      });
      expect(alias.reason, PathAliasReason.slugChange);
      expect(alias.hasVersionRange, isTrue);
      expect(alias.fromVer, isNull);
    });

    test('线上取值是蛇形：parentChange ↔ parent_change（无 SPEC：§7 取值为蛇形）', () {
      final PathAlias alias = PathAlias.fromJson(<String, Object?>{
        'old_path': 'p',
        'node_id': 'n',
        'reason': 'parent_change',
        'from_ver': '1.0.0',
        'to_ver': '1.1.0',
      });
      expect(alias.toJson()['reason'], 'parent_change');
      expect(
        PathAliasReason.fromWire('slug_change'),
        PathAliasReason.slugChange,
      );
    });
  });
}
