/// `PackFs` 的 `dart:io` 实现 —— 加载器里**唯一**直接触盘的文件。
///
/// 单独成文件不为分层洁癖：`Flutter` 之外的宿主要换即可换（测试用内存实现、
/// 将来若做 web 版换 `package:web`），而**探测与解析两层的字节一行不用动**。
/// 这正是 `R-04` 要的「路径探测与解析拆开」的落点 —— 换路径形态的成本被按在了
/// 这一个文件里。
library;

import 'dart:io';

import 'pack_fs.dart';

/// 走真实文件系统。
class DartIoPackFs implements PackFs {
  const DartIoPackFs();

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
}

/// 开发期的候选根目录：`<cwd>/content` 与 `<cwd>/../content`。
///
/// `SPEC-PACK-018` 钉的是「按**运行期 CWD** 找 `<仓根>/content/<空间>/dist/pack.json`」，
/// 于是从 `app/` 内跑（`flutter run` / `flutter test`）命中后者，从仓根跑命中前者。
/// 两条都给、先命中者优先 —— 不靠调用方记住自己在哪一层目录。
///
/// **制品形态的候选根不在这里**（exe 同级 `packs/`、iOS bundle 资源）：
/// 那是 `B8` 要补的，补法是往候选列表加一项，解析层不动（`R-04`）。
List<String> devPackRoots({String? cwd}) {
  final String base = cwd ?? Directory.current.path;
  return <String>['$base/content', '$base/../content'];
}
