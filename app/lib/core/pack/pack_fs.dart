/// 内容包的**磁盘形态**与**文件系统接缝**。
///
/// 为什么「探测」与「解析」必须拆成两类文件（`R-04`）：`SDP` §4.5 把
/// 「打包后内容包路径全部失效」列为**现在不办、后面无解**的风险 ——
/// 装成 exe / ipa 之后，开发期那条路径不存在，表象是「安装包能启动但一条内容
/// 都没有」。拆开的判据不是「分了几个类」，而是**加一条回落路径不该动解析代码**：
/// 所以本文件只有「包长什么样」与「怎么问文件系统」，零解析逻辑。
library;

import '../storage/store_fs.dart';

/// 一个知识空间在磁盘上的形态：同目录下 `manifest.json` + `dist/pack.json`。
///
/// `SPEC-PACK-018` 只钉死 `pack.json` 的位置（`<仓根>/content/<空间>/dist/pack.json`），
/// 清单在它上一级。**清单不是可选项**：`pack.json` 的 `meta` 只承载 `space` +
/// `version`（`SPEC-PACK-005`），而 `name` / `sixAxis` / `accent` / `order` /
/// `domainIds` 只在清单里 —— 少了清单，主题色与 Z0 排序就无从取值。
/// 换句话说，**分发单位是目录，不是一个 json 文件**。
class PackLayout {
  const PackLayout._();

  static const String manifestFileName = 'manifest.json';
  static const String distDirName = 'dist';
  static const String packFileName = 'pack.json';

  /// 清单路径（空间根目录下）。
  static String manifestPath(String spaceRoot) => '$spaceRoot/$manifestFileName';

  /// 产物路径（空间根目录的 `dist/` 下）。
  static String packPath(String spaceRoot) => '$spaceRoot/$distDirName/$packFileName';
}

/// 文件系统接缝 —— 探测与解析只通过它触盘。
///
/// 三个读方法刻意做成**总函数**（不抛异常）：`isFile` / `listDirs` / `readString`。
/// 加载器要回答的第一个问题是「这里为什么没有内容」，而一个从 `dart:io`
/// 穿出来的 `PathNotFoundException` 只会告诉调用方「挂了」，不会告诉用户
/// 「少了清单还是少了产物」。读不到一律 `null`，由探测层翻译成具体原因。
///
/// **方法声明在 [`StoreFs`](../storage/store_fs.dart)，本接口零方法。**
/// 原来这里自带三个声明，与存储三区的另外两个区各写一份 —— 加一个读方法要改
/// 三处，而三处必然分叉。现在只留一个**类型名**：`PackFs` = 「这次读的是内容包」，
/// 与「这次读的是什么」无关的能力全部在 `StoreFs`。本条不改变任何既有实现的
/// 义务（三个方法仍须实现），只是把它们收口到一处。
abstract interface class PackFs implements StoreFs {}
