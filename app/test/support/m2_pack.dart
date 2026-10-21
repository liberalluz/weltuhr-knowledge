/// 测试共用的 M2 包加载器。
///
/// 与 `alpha_pack.dart` 的分工：那份读**真实内容包**（`content/python`，六轴旧
/// 格式，`dist/` 不入库），这份读**新格式夹具**（`test/fixtures/m2`，入库）。
///
/// 存在的理由：`B13a` 笔 5 要把 12 个吃 α 包的用例切到新格式，而切换之前
/// 新解析层自己也需要一个「六段齐全、分支覆盖够」的样本。M1 只有 2 个行星、
/// 没有 `methods` 段，撑不起树 / 筛选 / 详情那几组断言。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/pack/pack_reader.dart';
import 'package:project_knowledge/core/json.dart';

/// M2 夹具根（相对 `app/`，`flutter test` 的 CWD）。
const String m2Root = 'test/fixtures/m2';

/// M2 包原文。
///
/// **不存在时明确失败，不 skip** —— 与 `alpha_pack.dart` 同口径：夹具缺失
/// 时跳过会让「CI 全绿」变成「这个包根本没被读过」。
String m2PackJson() {
  final File file = File('$m2Root/pack.json');
  if (!file.existsSync()) {
    fail('找不到 M2 夹具：${file.absolute.path}');
  }
  return file.readAsStringSync();
}

/// 解析 M2 包。
PackContent loadM2Pack() => readPack(m2PackJson());

/// 在 M2 原文上做一处改动，返回新的 JSON 文本。
///
/// 反例靠它生成而不是各存一份文件：改一处就要存一份，六份反例就是六份
/// 会与正例漂移的副本，而「反例只差一处」恰恰是本项目对夹具的硬要求。
String mutateM2(void Function(JsonMap pack) change) {
  final JsonMap pack = jsonDecode(m2PackJson()) as JsonMap;
  change(pack);
  return jsonEncode(pack);
}
