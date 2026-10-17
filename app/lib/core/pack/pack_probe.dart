/// 路径探测：找出「哪些目录确实是一个内容包」。
///
/// 只做**存在性**判断，不读一个字节的内容语义 —— 这正是 `R-04` 要的边界：
/// 换安装形态（exe 同级 / App Store bundle）时新增的是「候选根目录」，
/// 不是解析逻辑。
///
/// 失败**不当沉默的空列表**：`SDP` `R-04` 的表象是「应用能启动但一条内容都没有」，
/// 若探测只返回空列表，界面就分不清「还没装包」与「包装了但缺文件」。
library;

import 'pack_fs.dart';

/// 探测失败的具体原因 —— 每一条都对应一个可执行的修复动作。
enum PackProblemKind {
  /// 目录里没有 `manifest.json`：要么不是空间目录，要么清单没随包分发。
  missingManifest,

  /// 清单在、产物不在：`build.py` 没跑过，或 `dist/` 没随包分发。
  missingPack,

  /// 文件在但读不出来（权限 / 非 UTF-8 / 空文件）。
  unreadable,
}

/// 一条探测问题。
class PackProblem {
  const PackProblem({required this.kind, required this.path});

  final PackProblemKind kind;

  /// 出问题的文件路径（`unreadable` 时是那个读不出的文件）。
  final String path;

  @override
  String toString() => '${kind.name}: $path';
}

/// 一个**形态完整**的包位置（清单 + 产物都在）。是否能用另说 —— 那是解析层的事。
class PackLocation {
  const PackLocation({required this.spaceRoot});

  /// 空间根目录（`/` 结尾不带分隔符）。
  final String spaceRoot;

  String get manifestPath => PackLayout.manifestPath(spaceRoot);
  String get packPath => PackLayout.packPath(spaceRoot);
}

/// 一次探测的结果：找到的包 + 没成的目录及原因。两者**都返回**。
class ProbeResult {
  const ProbeResult({required this.locations, required this.problems});

  final List<PackLocation> locations;
  final List<PackProblem> problems;

  /// 一个包都没找到（**不等于**没有问题：可能有问题，也可能是空根）。
  bool get isEmpty => locations.isEmpty;
}

/// 路径探测器。
class PackProbe {
  const PackProbe(this._fs);

  final PackFs _fs;

  /// 扫一个根目录下的**每个子目录**，把形态完整的当成一个包。
  ///
  /// 结果按目录名排序 —— 包的发现顺序不能取决于文件系统的枚举顺序，
  /// 否则同一台机器两次启动的 `Z0` 顺序可能不同（`manifest.order` 才是排序键，
  /// 但顺序本身仍须可复现）。
  ProbeResult scanRoot(String root) {
    // 拷一份再排序：`PackFs` 允许返回不可变列表（`const []` 是合法实现），
    // 就地排序会在读实现上炸掉，而这跟探测逻辑毫无关系。
    final List<String> dirs = <String>[..._fs.listDirs(root)]..sort();
    final List<PackLocation> locations = <PackLocation>[];
    final List<PackProblem> problems = <PackProblem>[];

    for (final String name in dirs) {
      final ProbeResult single = probeSpace('$root/$name');
      locations.addAll(single.locations);
      problems.addAll(single.problems);
    }

    return ProbeResult(locations: locations, problems: problems);
  }

  /// 按候选根目录**依次**探测，同名空间以**先出现的**候选为准。
  ///
  /// 这是 `R-04` 的回落点：开发期用仓内 `content/`，装成制品后换成 exe 同级
  /// （`B8`）。加一条路径 = 往列表里再加一个根目录，解析层一行不动。
  /// 先出现者优先，是因为「开发期覆盖」比「制品内置」更好预期：本地改了包
  /// 就能看到，不必等打包。
  ProbeResult scanRoots(List<String> roots) {
    final List<PackLocation> locations = <PackLocation>[];
    final List<PackProblem> problems = <PackProblem>[];
    final Set<String> seen = <String>{};

    for (final String root in roots) {
      final ProbeResult single = scanRoot(root);
      for (final PackLocation location in single.locations) {
        if (seen.add(_spaceName(location.spaceRoot))) {
          locations.add(location);
        }
      }
      problems.addAll(single.problems);
    }

    return ProbeResult(locations: locations, problems: problems);
  }

  /// 探测**单个**空间目录。缺清单只报 `missingManifest`；缺产物报 `missingPack`。
  ProbeResult probeSpace(String spaceRoot) {
    final String manifestPath = PackLayout.manifestPath(spaceRoot);
    if (!_fs.isFile(manifestPath)) {
      return ProbeResult(
        locations: const <PackLocation>[],
        problems: <PackProblem>[
          PackProblem(kind: PackProblemKind.missingManifest, path: manifestPath),
        ],
      );
    }

    final String packPath = PackLayout.packPath(spaceRoot);
    if (!_fs.isFile(packPath)) {
      return ProbeResult(
        locations: const <PackLocation>[],
        problems: <PackProblem>[
          PackProblem(kind: PackProblemKind.missingPack, path: packPath),
        ],
      );
    }

    // 读不出来与「文件不在」是两件事：前者要查权限 / 编码，后者要查构建。
    for (final String path in <String>[manifestPath, packPath]) {
      if (_fs.readString(path) == null) {
        return ProbeResult(
          locations: const <PackLocation>[],
          problems: <PackProblem>[PackProblem(kind: PackProblemKind.unreadable, path: path)],
        );
      }
    }

    return ProbeResult(
      locations: <PackLocation>[PackLocation(spaceRoot: spaceRoot)],
      problems: const <PackProblem>[],
    );
  }

  /// `a/b/python` → `python`。
  String _spaceName(String spaceRoot) {
    final int cut = spaceRoot.lastIndexOf('/');
    return cut < 0 ? spaceRoot : spaceRoot.substring(cut + 1);
  }
}
