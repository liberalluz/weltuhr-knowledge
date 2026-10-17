/// 内容包的**磁盘形态**与**文件系统接缝**。
///
/// 为什么「探测」与「解析」必须拆成两类文件（`R-04`）：`SDP` §4.5 把
/// 「打包后内容包路径全部失效」列为**现在不办、后面无解**的风险 ——
/// 装成 exe / ipa 之后，开发期那条路径不存在，表象是「安装包能启动但一条内容
/// 都没有」。拆开的判据不是「分了几个类」，而是**加一条回落路径不该动解析代码**：
/// 所以本文件只有「包长什么样」与「怎么问文件系统」，零解析逻辑。
library;

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
/// 三件事刻意做成**总函数**（不抛异常）：`isFile` / `listDirs` / `readString`。
/// 加载器要回答的第一个问题是「这里为什么没有内容」，而一个从 `dart:io`
/// 穿出来的 `PathNotFoundException` 只会告诉调用方「挂了」，不会告诉用户
/// 「少了清单还是少了产物」。读不到一律 `null`，由探测层翻译成具体原因。
abstract interface class PackFs {
  /// 是否为**已存在且可读**的普通文件。
  bool isFile(String path);

  /// 列出一级子目录名（不含路径前缀），**不含**文件。目录不存在时返回空列表。
  List<String> listDirs(String path);

  /// 读 UTF-8 文本。不存在 / 权限不足 / 非 UTF-8 一律 `null`。
  String? readString(String path);
}
