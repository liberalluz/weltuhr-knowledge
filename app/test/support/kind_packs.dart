/// 测试共用的 M3 / M4 夹具加载器（**非载荷**两类包）。
///
/// 与 `m2_pack.dart` 的分工：那份是「载荷 + 方法」样本，演示 `kinds` 可多值；
/// 这份是**非载荷**的两类 —— M3 只有 `overlay`、M4 只有 `terrain`。前者六段
/// 全是空数组，后者只带边、不带节点。
///
/// 存在的理由：`readPack` 对四类包走同一条路径，但此前跑过它的样本只有载荷
/// 那一类 —— 「`kinds` 与四个 facts 一一对应」是**双向**校验，另一向
/// （overlay / terrain 声明了就必须给、给了就必须声明）一个用例也没有。
/// 装/卸四类包（`B14` 笔 4）之前，先把两个非载荷样本立住。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/json.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';

/// M3 夹具根（相对 `app/`，`flutter test` 的 CWD）。
const String m3Root = 'test/fixtures/m3';

/// M4 夹具根。
const String m4Root = 'test/fixtures/m4';

/// 夹具原文。**不存在时明确失败，不 skip** —— 与 `m2_pack.dart` 同口径：
/// 夹具缺失时跳过会让「CI 全绿」变成「这个包根本没被读过」。
String _fixtureJson(String root) {
  final File file = File('$root/pack.json');
  if (!file.existsSync()) {
    fail('找不到夹具：${file.absolute.path}');
  }
  return file.readAsStringSync();
}

String m3PackJson() => _fixtureJson(m3Root);
String m4PackJson() => _fixtureJson(m4Root);

/// 解析 M3（`overlay`）包。
PackContent loadM3Pack() => readPack(m3PackJson());

/// 解析 M4（`terrain`）包。
PackContent loadM4Pack() => readPack(m4PackJson());

/// 在夹具原文上做一处改动，返回新的 JSON 文本。
///
/// 反例靠它生成而不是各存一份文件：改一处存一份，反例就会与正例漂移，
/// 而「反例只差一处」是本项目对夹具的硬要求。
String _mutate(String root, void Function(JsonMap pack) change) {
  final JsonMap pack = jsonDecode(_fixtureJson(root)) as JsonMap;
  change(pack);
  return jsonEncode(pack);
}

String mutateM3(void Function(JsonMap pack) change) => _mutate(m3Root, change);
String mutateM4(void Function(JsonMap pack) change) => _mutate(m4Root, change);

/// 在 M4 上派生一个地形包原文：边由入参给，`terrain.edge_counts` 由边集**现算**。
///
/// 只换 `plugin_id` / `namespace` / `name` / `deps` / `edges` / `terrain` 六处，
/// 其余字段与 M4 逐字相同 —— 夹具「反例只差一处」是本项目的硬要求。
///
/// `edge_counts` 不手写：手写就会与边集漂移，而 `TC-FND-016`–`017` 抓的正是
/// 「摘要与实扫不符」。这里让摘要跟着边集走，用例只表达「边怎么摆」。
String m4VariantJson({
  required String pluginId,
  required List<({String from, String to, EdgeStrength strength})> edges,
}) => mutateM4((JsonMap pack) {
  final int required = edges
      .where(
        (({String from, String to, EdgeStrength strength}) edge) =>
            edge.strength == EdgeStrength.required,
      )
      .length;
  pack['plugin_id'] = pluginId;
  pack['namespace'] = pluginId;
  pack['name'] = 'M4 地形变体（$pluginId）';
  pack['deps'] = <Object?>[];
  pack['edges'] = <Object?>[
    for (final ({String from, String to, EdgeStrength strength}) edge in edges)
      <String, Object?>{
        'type': 'prerequisite',
        'from_id': edge.from,
        'to_id': edge.to,
        'strength': edge.strength.name,
      },
  ];
  pack['terrain'] = <String, Object?>{
    'edge_counts': <String, Object?>{
      'required': required,
      'recommended': edges.length - required,
    },
    'axes_covered': <String>['major'],
  };
});
