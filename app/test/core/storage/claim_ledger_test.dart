import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/path_claims.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/storage/claim_ledger.dart';

PathClaim _claim(String path, {String nodeId = 'p:1', ClaimState? state}) => PathClaim(
  path: path,
  nodeId: nodeId,
  state: state ?? ClaimState.live,
);

void main() {
  group('ClaimLedger（台账形态）', () {
    test('空台账序列化后读回仍是空，两次序列化同一串字节（无 SPEC：台账形态本笔定）', () {
      final ClaimLedger ledger = ClaimLedger.empty();
      final String once = ledger.toJson();

      expect(ClaimLedger.fromJson(once).isEmpty, isTrue);
      expect(ledger.toJson(), once);
    });

    test('按 path 升序序列化 —— 结果与写入顺序无关（无 SPEC：台账形态本笔定）', () {
      // 不定序的后果不是「文件难看」：同一份台账两次落盘产出不同字节，
      // 每次装包都会留下一个「内容没变、diff 全变」的提交。
      final ClaimLedger forward = ClaimLedger(<PathClaim>[
        _claim('a'),
        _claim('b'),
      ]);
      final ClaimLedger backward = ClaimLedger(<PathClaim>[
        _claim('b'),
        _claim('a'),
      ]);

      expect(forward.toJson(), backward.toJson());
    });

    test('`schema` 不认识即拒，不猜字段含义（无 SPEC：台账形态本笔定）', () {
      // 猜一版的后果：`state` 读成另一个含义，该拦的复用拦不住且没有断言会红。
      expect(
        () => ClaimLedger.fromJson('{"schema":2,"claims":[]}'),
        throwsFormatException,
      );
    });

    test('同一个 path 两份账即拒 —— 谁现役说不清（无 SPEC：台账形态本笔定）', () {
      const String twoOwners =
          '{"schema":1,"claims":['
          '{"path":"a","node_id":"x:1","state":"live"},'
          '{"path":"a","node_id":"y:1","state":"tombstone"}]}';

      expect(() => ClaimLedger.fromJson(twoOwners), throwsFormatException);
    });

    test('同 path 再写一条即覆盖，且旧的那份不被就地改（无 SPEC：台账不可变是写盘失败不留中间态的前提）', () {
      final ClaimLedger before = ClaimLedger(<PathClaim>[
        _claim('a', nodeId: 'x:1', state: ClaimState.tombstone),
      ]);

      final ClaimLedger after = before.withClaim(_claim('a', nodeId: 'x:1'));

      expect(after.length, 1);
      expect(after.claimOf('a')!.state, ClaimState.live);
      expect(
        before.claimOf('a')!.state,
        ClaimState.tombstone,
        reason: '旧台账被就地改写，写盘失败时就会留下「内存里已改、盘上没改」',
      );
    });
  });
}
