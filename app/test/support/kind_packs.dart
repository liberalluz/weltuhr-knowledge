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
