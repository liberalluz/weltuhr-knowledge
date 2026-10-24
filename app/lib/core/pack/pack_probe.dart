/// 路径探测：找出「哪些目录确实是一个内容包」，以及**它是哪一类**。
///
/// 只做**存在性**判断，不读一个字节的内容语义 —— 这正是 `R-04` 要的边界：
/// 换安装形态（exe 同级 / App Store bundle）时新增的是「候选根目录」，
/// 不是解析逻辑。
///
/// 失败**不当沉默的空列表**：`SDP` `R-04` 的表象是「应用能启动但一条内容都没有」，
/// 若探测只返回空列表，界面就分不清「还没装包」与「包装了但缺文件」。
library;

import '../enums.dart';
import 'pack_fs.dart';

/// 探测失败的具体原因 —— 每一条都对应一个可执行的修复动作。
///
/// ⚠️ `B14` 起只剩两条：旧形态的 `missingManifest`（清单在不在）与
/// `missingPack`（产物在不在）是**两件可分别修的事**，单文件形态下它们合成
/// 同一件事 —— `pack.json` 不在，要么 `build.py` 没跑过，要么产物没随包分发。
/// 拆成两条只会让调用方以为有两种修法。
enum PackProblemKind {
  /// 目录里没有 `pack.json`：要么不是包目录，要么产物没随包分发。
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

/// 一个**形态完整**的包位置（`pack.json` 在且读得出）。
///
/// 是否能用、到底属于哪几类，另说 —— 那是解析层的事（`Pack.kinds[]`）。
class PackLocation {
  const PackLocation({required this.kind, required this.packRoot});

  /// 这个位置是在**哪一类**的候选根下被探到的。
  ///
  /// ⚠️ **不是**权威的 `Pack.kinds[]`：探测层不读内容，只能是「本次查询问的是
  /// 哪一类」。同一个包若被列在两类候选根下，会产出一条 `payload` 与一条
  /// `method` 两个位置、`packRoot` 相同。装载层须按 `packRoot` 合并，
  /// 以解析出的 `kinds[]` 为准。
  final PackKind kind;

  /// 包根目录（`/` 结尾不带分隔符）。
  final String packRoot;

  String get packPath => PackLayout.packPath(packRoot);
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

  /// 扫一个根目录下的**每个子目录**，把含 `pack.json` 的当成一个 [kind] 类的包。
  ///
  /// 结果按目录名排序 —— 包的发现顺序不能取决于文件系统的枚举顺序，
  /// 否则同一台机器两次启动的 `Z0` 顺序可能不同（`sort_order` 才是排序键，
  /// 但顺序本身仍须可复现）。
  ProbeResult scanRoot(String root, PackKind kind) {
    // 拷一份再排序：`PackFs` 允许返回不可变列表（`const []` 是合法实现），
    // 就地排序会在读实现上炸掉，而这跟探测逻辑毫无关系。
    final List<String> dirs = <String>[..._fs.listDirs(root)]..sort();
    final List<PackLocation> locations = <PackLocation>[];
    final List<PackProblem> problems = <PackProblem>[];

    for (final String name in dirs) {
      final ProbeResult single = probePack('$root/$name', kind);
      locations.addAll(single.locations);
      problems.addAll(single.problems);
    }

    return ProbeResult(locations: locations, problems: problems);
  }

  /// 按 `kind` **分组**探测：每个 kind 一组候选根，组内按顺序、同名目录先出现者优先。
  ///
  /// 这是 `R-04` 的回落点：开发期用仓内 `content/`，装成制品后换成 exe 同级
  /// （`B8`）。加一条路径 = 往某个 kind 的列表里再加一个根目录，解析层一行不动。
  /// 先出现者优先，是因为「开发期覆盖」比「制品内置」更好预期：本地改了包
  /// 就能看到，不必等打包。
  ///
  /// **为什么按 kind 分组而不是「根下按 kind 分子目录」**：`Pack.kinds[]` 可多值
  /// （`pack.dart` 文件头明写「`kinds[]` 不是判别符」），一个包既是载荷又带方法是
  /// 合法形态。让目录名承载 kind，多 kind 包必然只被算进其中一类。
  /// 分组的直接后果是：**同一个根可以列给多个 kind**，同一个包会在各类查询里
  /// 各出现一次（`packRoot` 相同、`kind` 不同）—— 这不是 bug，是「kind 是查询
  /// 维度，不是存储位置」的代价。
  ///
  /// 去重只在**同一个 kind 内**按目录名进行：跨 kind 同名不算重复（那是两个
  /// 不同的问题，各有各的答案）。
  ProbeResult scanRoots(Map<PackKind, List<String>> roots) {
    final List<PackLocation> locations = <PackLocation>[];
    final List<PackProblem> problems = <PackProblem>[];
    final Set<String> seen = <String>{};

    for (final MapEntry<PackKind, List<String>> entry in roots.entries) {
      // 每个 kind 独立去重：`seen` 按 kind 清空，否则后一类会被前一类挤掉。
      seen.clear();
      for (final String root in entry.value) {
        final ProbeResult single = scanRoot(root, entry.key);
        for (final PackLocation location in single.locations) {
          if (seen.add(_dirName(location.packRoot))) {
            locations.add(location);
          }
        }
        problems.addAll(single.problems);
      }
    }

    return ProbeResult(locations: locations, problems: problems);
  }

  /// 探测**单个**包目录。没有 `pack.json` 报 `missingPack`。
  ProbeResult probePack(String packRoot, PackKind kind) {
    final String packPath = PackLayout.packPath(packRoot);
    if (!_fs.isFile(packPath)) {
      return ProbeResult(
        locations: const <PackLocation>[],
        problems: <PackProblem>[
          PackProblem(kind: PackProblemKind.missingPack, path: packPath),
        ],
      );
    }

    // 读不出来与「文件不在」是两件事：前者要查权限 / 编码，后者要查构建。
    if (_fs.readString(packPath) == null) {
      return ProbeResult(
        locations: const <PackLocation>[],
        problems: <PackProblem>[
          PackProblem(kind: PackProblemKind.unreadable, path: packPath),
        ],
      );
    }

    return ProbeResult(
      locations: <PackLocation>[PackLocation(kind: kind, packRoot: packRoot)],
      problems: const <PackProblem>[],
    );
  }

  /// `a/b/python` → `python`。
  String _dirName(String packRoot) {
    final int cut = packRoot.lastIndexOf('/');
    return cut < 0 ? packRoot : packRoot.substring(cut + 1);
  }
}
