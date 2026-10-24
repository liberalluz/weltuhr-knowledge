/// `PathClaim` 台账的**文件形态**（`entity-fields` §6 · `path-rules` `P-14`）。
///
/// `entity-fields` §6 只定义了实体，没定义「这一堆 claim 存哪、长什么样」。
/// 本笔定为 `<可写内容区>/claims.json`：
///
/// ```json
/// { "schema": 1, "claims": [ { "path": "...", "node_id": "...", "state": "live" } ] }
/// ```
///
/// 三条形态理由：
///
/// 1. **一次原子写落全部 claim**。拆成「一 claim 一文件」就没有跨文件的原子性：
///    写到第三个文件失败时，墓碑与现役会一半新一半旧 —— 而「这个地址现在归谁」
///    正是冲突判定唯一要看的东西。
/// 2. **`schema` 键**（`claimsSchemaVersion`）。台账在用户机器上会比代码活得久，
///    没有版本号就只能靠猜。
/// 3. **不可变**：改一次产生一份新台账。装载器据此做到「要么全写、要么一字不写」
///    —— 可变的台账在写盘失败时会留下「内存里已改、盘上没改」的中间态，而这个
///    中间态没有任何地方看得见。
///
/// ## 解析顺序（为什么不是「先查 alias」）
///
/// `live` → `tombstone` → `alias`（`path_claims.dart` 文件头）。本类只管前两者：
/// `alias` 是 `PathAlias`，本笔不涉及装载流程 —— 它服务的是「骨架升版改主父」，
/// 归 `B13b` 之后的骨架版本迁移。
library;

import 'dart:convert';

import '../constants.dart';
import '../entities/path_claims.dart';
import '../json.dart';

/// 一份台账。**不可变**：任何修改都返回新的一份。
class ClaimLedger {
  ClaimLedger(Iterable<PathClaim> claims)
    : _byPath = Map<String, PathClaim>.unmodifiable(<String, PathClaim>{
        for (final PathClaim claim in claims) claim.path: claim,
      });

  factory ClaimLedger.empty() => ClaimLedger(const <PathClaim>[]);

  /// 读一份台账。**坏数据一律拒，不猜**：`schema` 不认识、`path` 重复都抛
  /// [FormatException]，由装载层翻译成给用户看的问题。
  ///
  /// 为什么「`path` 重复」必须是错而不是「后者胜」：同一个地址两份账时
  /// 「谁现役」没有答案，而装载器的每一个判断都建立在这个答案上。
  factory ClaimLedger.fromJson(String text) {
    final Object? decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw FormatException('台账顶层必须是对象，实际是 ${decoded.runtimeType}');
    }
    final JsonMap json = decoded.map(
      (Object? key, Object? value) => MapEntry<String, Object?>('$key', value),
    );

    final int schema = requireInt(json, 'schema');
    if (schema != claimsSchemaVersion) {
      throw FormatException(
        '台账 `schema` 是 $schema，本版本只认 $claimsSchemaVersion '
        '—— 不认识的格式不猜',
      );
    }

    final List<PathClaim> parsed = <PathClaim>[];
    for (final JsonMap raw in requireMapList(json, 'claims')) {
      parsed.add(PathClaim.fromJson(raw));
    }

    final ClaimLedger ledger = ClaimLedger(parsed);
    if (ledger.length != parsed.length) {
      throw FormatException(
        '台账里有重复的 `path`（${parsed.length} 条 claim 只落到 '
        '${ledger.length} 个地址）—— 同一个地址两份账，谁现役说不清',
      );
    }
    return ledger;
  }

  final Map<String, PathClaim> _byPath;

  /// 按 `path` 升序。**排序不等到写盘时才做**：同一份台账两次序列化必须得到
  /// 同一串字节，否则每装一次包就多一个「内容没变、diff 全变」的提交。
  late final List<PathClaim> claims = List<PathClaim>.unmodifiable(
    (<String>[..._byPath.keys]..sort()).map((String path) => _byPath[path]!),
  );

  int get length => _byPath.length;

  bool get isEmpty => _byPath.isEmpty;

  PathClaim? claimOf(String path) => _byPath[path];

  /// 写入一条（同 `path` 覆盖 —— 覆盖的语义只有两种用途：墓碑转现役、现役转墓碑）。
  ClaimLedger withClaim(PathClaim claim) =>
      _with(<PathClaim>[claim]);

  ClaimLedger withClaims(Iterable<PathClaim> claims) => _with(claims);

  ClaimLedger _with(Iterable<PathClaim> incoming) {
    final Map<String, PathClaim> next = <String, PathClaim>{..._byPath};
    for (final PathClaim claim in incoming) {
      next[claim.path] = claim;
    }
    // 走 `values` 而不是 `next.entries`：`ClaimLedger` 的构造体自己会按
    // `path` 建索引，这里只是把改过的集合交回去。
    return ClaimLedger(next.values);
  }

  /// 序列化。缩进两格 + 末尾一个换行 —— 这份文件会被人打开看（排查
  /// 「为什么这个包装不上」时的第一现场），不该是一行几 KB 的压缩 JSON。
  String toJson() {
    final String body = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'schema': claimsSchemaVersion,
        'claims': claims.map((PathClaim c) => c.toJson()).toList(),
      },
    );
    return '$body\n';
  }
}
