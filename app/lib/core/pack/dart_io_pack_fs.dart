/// `PackFs` 的 `dart:io` 实现 —— 加载器里**唯一**直接触盘的文件。
///
/// 单独成文件不为分层洁癖：`Flutter` 之外的宿主要换即可换（测试用内存实现、
/// 将来若做 web 版换 `package:web`），而**探测与解析两层的字节一行不用动**。
/// 这正是 `R-04` 要的「路径探测与解析拆开」的落点 —— 换路径形态的成本被按在了
/// 这一个文件里。
library;

import 'dart:io';

import '../constants.dart';
import '../enums.dart';
import '../storage/store_fs.dart';
import 'pack_fs.dart';

/// 走真实文件系统。
///
/// 同时实现三个区的能力接口：读（`PackFs`）· 读 + 原子写（`WritableStoreFs`）·
/// 读 + 追加（`AppendOnlyStoreFs`）。**这不是说一个实例可以随便越区** ——
/// 越界与否由 `StoreLayout` 判（构造时拒绝重叠根，`pathIn` 拒绝 `..` 逃逸），
/// 本类只负责「给定一个已经合法的路径，怎么把它写下去」。
class DartIoPackFs implements PackFs, WritableStoreFs, AppendOnlyStoreFs {
  const DartIoPackFs();

  /// 临时文件序号。同一进程内并发写同一文件时，靠它拿到不同的临时名 ——
  /// 用时间戳会撞（同一微秒内两次调用），用随机数会让失败不可复现。
  static int _tempSeq = 0;

  @override
  bool isFile(String path) {
    try {
      return File(path).statSync().type == FileSystemEntityType.file;
    } on FileSystemException {
      return false;
    }
  }

  @override
  List<String> listDirs(String path) {
    final Directory directory = Directory(path);
    try {
      if (!directory.existsSync()) {
        return const <String>[];
      }
      final List<String> names = <String>[];
      for (final FileSystemEntity entity in directory.listSync(followLinks: false)) {
        if (entity is Directory) {
          names.add(entity.uri.pathSegments.where((String s) => s.isNotEmpty).last);
        }
      }
      return names;
    } on FileSystemException {
      return const <String>[];
    }
  }

  @override
  String? readString(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    } on FormatException {
      // 非 UTF-8：包必须是 UTF-8，读不出来就是坏包，不猜编码。
      return null;
    }
  }

  @override
  bool ensureDir(String path) {
    try {
      Directory(path).createSync(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// 原子写：写临时文件 → `flush` → rename。
  ///
  /// **能保证什么**：目标路径上永远不会出现半截内容。要么是旧内容，要么是新内容。
  /// 这是「用户攒出来的事实」最要紧的一条 —— 断电留下一个零字节的
  /// `claims.json`，等于把整份 PathClaim 台账清空，而且没有任何日志说发生过。
  ///
  /// **不能保证什么（如实登记）**：目标**已存在**时，「删旧 + rename」在
  /// Windows 上有一个极短窗口，此刻目标路径不存在。POSIX 上 `rename` 覆盖是
  /// 原子的，走不到那条分支；Windows 上要做到无缝得用
  /// `MoveFileEx(MOVEFILE_REPLACE_EXISTING)`，Dart 没暴露。所以这里先试一次
  /// rename（POSIX 命中即结束），失败才退到「删旧 + rename」——
  /// 而不是无条件先删。
  @override
  bool writeStringAtomic(String path, String content) {
    final String tempPath = '$path$atomicTempSuffix${_tempSeq++}';
    final File temp = File(tempPath);
    try {
      temp.writeAsStringSync(content, flush: true);
    } on FileSystemException {
      _deleteQuietly(temp);
      return false;
    }

    final File target = File(path);
    try {
      temp.renameSync(path);
      return true;
    } on FileSystemException {
      // 目标已存在且平台不允许覆盖（Windows）。旧内容先让位，再换新的。
      try {
        if (target.existsSync()) {
          target.deleteSync();
        }
        temp.renameSync(path);
        return true;
      } on FileSystemException {
        _deleteQuietly(temp);
        return false;
      }
    }
  }

  @override
  bool appendLine(String path, String line) {
    final String payload = line.endsWith(eventLogLineBreak)
        ? line
        : '$line$eventLogLineBreak';
    try {
      // 追加写不做 temp + rename：那会把整个日志重抄一遍，而日志是只增的。
      // 目录必须已存在 —— 半行写入比「写不进去」更糟，所以这里不替你建目录。
      File(path).writeAsStringSync(payload, mode: FileMode.append, flush: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// 临时文件删不掉不影响结果：它带 `.tmp` 后缀，不会被当成包文件读。
  void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } on FileSystemException {
      // 有意空：清理失败的唯一后果是留一个 .tmp 文件。
    }
  }
}

/// 开发期的候选根目录，**按 kind 分组**：`<cwd>/content` 与 `<cwd>/../content`。
///
/// `SPEC-PACK-018` 钉的是「按**运行期 CWD** 找 `<包根>/pack.json`」，
/// 于是从 `app/` 内跑（`flutter run` / `flutter test`）命中后者，从仓根跑命中前者。
/// 两条都给、先命中者优先 —— 不靠调用方记住自己在哪一层目录。
///
/// ⚠️ **分组 ≠ 分子目录**（`B14`）：同一个根出现在四类的列表里是**预期**的 ——
/// kind 是「这次查的是哪一类」，不是「文件必须放在 `<根>/<kind>/` 下」
/// （`Pack.kinds[]` 可多值，用目录名承载 kind 必然漏）。代价是同一个包在四类
/// 查询里各出现一次（`packRoot` 相同、`kind` 不同），装载层须按 `packRoot` 合并、
/// 以解析出的 `Pack.kinds[]` 为准。开发期盘上尚未按 kind 物理分区，
/// 这一层现在给不出更细的答案 —— 但它给了调用方**一个可改的位置**：
/// 将来某类包单独落目录，只改这里，探测与解析一行不动（`R-04`）。
///
/// **制品形态的候选根不在这里**（exe 同级 `packs/`、iOS bundle 资源）：
/// 那是 `B8` 要补的，补法是往候选列表加一项，解析层不动。
Map<PackKind, List<String>> devPackRoots({String? cwd}) {
  final String base = cwd ?? Directory.current.path;
  // `unmodifiable`：四个 key 共用一份列表，任一处被就地修改都会让另外三类
  // 悄悄换掉搜索路径 —— 那种错查起来要跨两层。
  final List<String> shared = List<String>.unmodifiable(<String>[
    '$base/content',
    '$base/../content',
  ]);
  return <PackKind, List<String>>{
    for (final PackKind kind in PackKind.values) kind: shared,
  };
}
