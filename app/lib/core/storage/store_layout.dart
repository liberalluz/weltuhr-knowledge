/// 存储三区的**物理落点**（`entity-fields.md` §〇）。
///
/// 这里的职责只有一件事：把三个区根收在一个对象里，并在构造时**拒绝互相包含的
/// 布局**。为什么这条校验值钱 —— 三区重叠在开发机上永远测不出来（仓内目录天然
/// 分开），只在用户机器上出现：自定义数据目录、把数据盘挂到 `/content` 下、
/// 在 Windows 上把 `%APPDATA%` 指到安装目录里。那时可写区的原子写会落到只读
/// 分发区里，包正文被本机的写操作改写，而**没有任何断言会红** —— 表象是
/// 「重装一次就正常了」。
///
/// **根路径全部由调用方注入**，本层不做平台解析。理由与 `PACK-018` 一致：
/// 路径形态是探测层的事，制品期形态（exe 同级 / App Store bundle）归 `B8`。
/// 在这里内置 `%APPDATA%` 等于抢了 `B8` 的活，且产品目录名会变成一处
/// 谁都不敢改的口径。
library;

import '../constants.dart';
import '../enums.dart';
import '../errors.dart';

/// 三区根目录。构造即校验，不合法直接抛 [InvalidStoreLayoutError]。
///
/// 三个根都在构造时**归一化**（`\` → `/`、去 `.` 段、消 `..` 段、去尾分隔符），
/// 于是 `'data/'` 与 `'./data'` 与 `'data'` 是同一个根 —— 否则「重叠」判定会被
/// 三种写法绕过，而它们本就是同一个目录。
class StoreLayout {
  StoreLayout({
    required String readOnlyRoot,
    required String writableRoot,
    required String eventRoot,
  }) : readOnlyRoot = normalizeStorePath(readOnlyRoot),
       writableRoot = normalizeStorePath(writableRoot),
       eventRoot = normalizeStorePath(eventRoot) {
    _verify();
  }

  /// 只读分发区：包正文、骨架。**只能读**。
  final String readOnlyRoot;

  /// 可写内容区：`S4` 自建、个人覆盖、墓碑。
  final String writableRoot;

  /// 事件日志区：只 append。
  final String eventRoot;

  /// 某区的根。
  String rootOf(StoreZone zone) {
    switch (zone) {
      case StoreZone.readOnly:
        return readOnlyRoot;
      case StoreZone.writable:
        return writableRoot;
      case StoreZone.event:
        return eventRoot;
    }
  }

  /// 把**区内相对路径**解析成绝对路径；越出本区返回 `null`。
  ///
  /// 越界不走「拼完再检查」的老路（那要求调用方记得检查），而是由这里直接给
  /// `null`。`..` 能逃出区根的话，三区分离就只剩三个变量名 ——
  /// 而 `'../../content/pack.json'` 这种相对路径在插件包里是**作者可控的输入**。
  String? pathIn(StoreZone zone, String relative) {
    final String root = rootOf(zone);
    final String joined = normalizeStorePath('$root$pathSeparator$relative');
    return _under(joined, root) ? joined : null;
  }

  void _verify() {
    for (final StoreZone zone in StoreZone.values) {
      final String root = rootOf(zone);
      if (root.isEmpty) {
        throw InvalidStoreLayoutError.empty(zone, root);
      }
    }

    const List<StoreZone> zones = StoreZone.values;
    for (int i = 0; i < zones.length; i++) {
      for (int j = i + 1; j < zones.length; j++) {
        final String a = rootOf(zones[i]);
        final String b = rootOf(zones[j]);
        if (_under(a, b) || _under(b, a)) {
          throw InvalidStoreLayoutError.overlapping(zones[i], a, b);
        }
      }
    }
  }
}

/// 归一化一个区根。公开是因为测试要直接断言归一化结果 ——
/// 重叠判定的正确性依赖它，而它是纯函数。
String normalizeStorePath(String raw) {
  final String unified = raw.replaceAll(r'\', pathSeparator);
  final List<String> parts = <String>[];
  for (final String part in unified.split(pathSeparator)) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    // `..` 只在还能退的时候退：已经退到起点（相对路径）就把它留着，
    // 否则 `../data` 会被归一化成 `data` —— 两个不同的位置变成同一个根。
    if (part == '..' && parts.isNotEmpty && parts.last != '..') {
      parts.removeLast();
      continue;
    }
    parts.add(part);
  }
  final String joined = parts.join(pathSeparator);
  return unified.startsWith(pathSeparator) ? '$pathSeparator$joined' : joined;
}

/// [path] 是否等于 [root] 或在其之下。
///
/// **按路径段比，不按字符串前缀**：`/data` 与 `/database` 字符串同前缀却是两个
/// 目录，用 `startsWith(root)` 会把合法布局判成重叠。
bool _under(String path, String root) {
  if (path == root) {
    return true;
  }
  final String prefix = root.endsWith(pathSeparator)
      ? root
      : '$root$pathSeparator';
  return path.startsWith(prefix);
}
