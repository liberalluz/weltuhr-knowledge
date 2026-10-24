/// 装 / 卸一个插件包（`B14` 笔 4）。
///
/// 这一段此前**全仓不存在**：`readPack` 零生产调用方、`PackProbe` 零生产调用方，
/// 于是「四类包可装可卸」这条出口判据没有一行承载代码。本类把它接起来，
/// 并且只接「装 / 卸」两件事 —— 不建「已安装包注册表文件」，也不做依赖求解。
///
/// ## 五个阶段，任一阶段有问题就一个字节都不写
///
/// 探测 → 解析 → 三元校验（`validatePack`）→ 台账冲突（`P-16` / `P-14`）→ 落盘。
///
/// **半装比不装更糟**：装了半个包，界面显示一半内容，而卸载时按「全装」清账 ——
/// 于是下一次装同一个包，遇到的是自己上次留下的半份账。
///
/// ## 三件事本笔不做（都是「规格没写过」，不是漏了）
///
/// 1. **校验 `deps` 区间**。`P-16` 只把 `path_reservations[]` 定为装前判据；
///    依赖求解要读另一个包的 `version`，那需要一张已安装清单 —— 本笔没有。
/// 2. **物化 `attach_to`**。边**已经在包数据里**（`entity-fields` §3 要求每个节点
///    都有 `main` 父边，骨架父也不例外，`M1` / `M2` 两份夹具都这么写）。
///    装载器若再补一条，同一对端点就有两条 `main` 边，「主父是谁」当场两个答案。
///    所以这里的「物化」= **验证它确实存在且唯一**（`validatePack` 第 ⑦ 步）。
/// 3. **写 `PathAlias`**。它服务的是「骨架升版改主父」，归骨架版本迁移，不在装 / 卸。
library;

import 'dart:convert';

import '../constants.dart';
import '../entities/edge.dart';
import '../entities/pack.dart';
import '../entities/path_claims.dart';
import '../enums.dart';
import '../graph/parent_index.dart';
import '../json.dart';
import '../storage/claim_ledger.dart';
import '../storage/store_fs.dart';
import '../storage/store_layout.dart';
import 'pack_fs.dart';
import 'pack_probe.dart';
import 'pack_reader.dart';
import 'triple_validator.dart';

/// 装成功后的一个包。
class InstalledPack {
  const InstalledPack({
    required this.packRoot,
    required this.content,
    required this.paths,
    required this.claims,
  });

  /// 包根目录（`pack.json` 所在的那一层）。
  final String packRoot;

  final PackContent content;

  /// 节点 `id → path`，装包时算出的那份（非载荷包为空）。
  final Map<String, String> paths;

  /// 本次写入台账的那些 claim。
  final List<PathClaim> claims;

  String get pluginId => content.pack.pluginId;

  /// 挂到骨架上的那个节点 id（`payload.attach_to`；非载荷包为 `null`）。
  String? get attachTo => content.pack.payload?.attachTo;

  /// 跨包 `main` 边（`P-15` 的唯一例外）。见文件头第 2 条：**不是本类造的**。
  ParentEdge? get attachEdge {
    for (final ParentEdge edge in content.edges.whereType<ParentEdge>()) {
      if (edge.isMain && ParentIndex.isSkeleton(edge.parentId)) {
        return edge;
      }
    }
    return null;
  }

  /// 跨包 `path`。注入过骨架 `path` 才有值 —— 这正是装包必须注入的理由。
  String? pathOf(String nodeId) => content.parents.pathOf(nodeId);
}

/// 装包结果。**失败时 [installed] 为 `null`，且台账一个字都没改。**
class InstallResult {
  const InstallResult._({required this.problems, this.installed});

  factory InstallResult.failed(List<String> problems) =>
      InstallResult._(problems: List<String>.unmodifiable(problems));

  factory InstallResult.ok(InstalledPack installed) =>
      InstallResult._(problems: const <String>[], installed: installed);

  final List<String> problems;
  final InstalledPack? installed;

  bool get ok => installed != null;
}

/// 卸包结果。
class UninstallResult {
  const UninstallResult._({
    required this.pluginId,
    required this.tombstoned,
    required this.problems,
  });

  factory UninstallResult.failed(String pluginId, List<String> problems) =>
      UninstallResult._(
        pluginId: pluginId,
        tombstoned: 0,
        problems: List<String>.unmodifiable(problems),
      );

  factory UninstallResult.ok(String pluginId, int tombstoned) =>
      UninstallResult._(
        pluginId: pluginId,
        tombstoned: tombstoned,
        problems: const <String>[],
      );

  final String pluginId;

  /// 本次转成墓碑的条目数（已经是墓碑的不重复转）。
  final int tombstoned;

  final List<String> problems;

  bool get ok => problems.isEmpty;
}

/// 装载器。
class PackLoader {
  PackLoader({
    required this.layout,
    required this.packFs,
    required this.storeFs,
    required this.skeletonPaths,
  });

  /// 三区布局。台账路径由它派生 —— 装载器**不自己拼路径**：`StoreLayout.pathIn`
  /// 是唯一的越界闸门，绕过它就只剩调用方自觉。
  final StoreLayout layout;

  /// 只读分发区：包正文从这里读。
  final PackFs packFs;

  /// 可写内容区：台账写这里（只有原子写，没有「截断再写」）。
  final WritableStoreFs storeFs;

  /// 骨架节点 `id → path`。不注入的话载荷节点的主父链到骨架就断，
  /// `validatePack` 会以 `E-PATH-PARENT` 拒装 —— 而那才是对的：算不出 `path`
  /// 的包装进来也定位不到。
  final Map<String, String> skeletonPaths;

  /// 内存里的已装清单。**不是持久事实** —— 持久事实是台账：重启后本表为空，
  /// 但 [uninstall] 仍能从台账找出该卸的条目。
  final Map<String, InstalledPack> _installed = <String, InstalledPack>{};

  /// 台账落点：`<可写内容区>/claims.json`。
  late final String claimsPath = _resolveClaimsPath();

  String _resolveClaimsPath() {
    final String? path = layout.pathIn(StoreZone.writable, claimsFileName);
    if (path == null) {
      // 结构上不可能：`claims.json` 没有分隔符、也没有 `..`。
      throw StateError('`$claimsFileName` 必落在可写区内，当前布局给不出路径');
    }
    return path;
  }

  InstalledPack? installedOf(String pluginId) => _installed[pluginId];

  /// 装一个包。
  InstallResult install(PackLocation location) {
    final List<String> problems = <String>[];

    // ① 探测。位置可能是上一次扫描的产物，装之前再看一眼 —— 磁盘会变。
    final ProbeResult probe = PackProbe(packFs).probePack(
      location.packRoot,
      location.kind,
    );
    for (final PackProblem problem in probe.problems) {
      problems.add(_probeProblemText(problem));
    }
    if (probe.locations.isEmpty) {
      return InstallResult.failed(problems);
    }

    final String? text = packFs.readString(location.packPath);
    if (text == null) {
      problems.add(
        '`${location.packPath}` 刚才还读得出、现在读不出来了 —— 装包中止',
      );
      return InstallResult.failed(problems);
    }

    // ② 解析。一次报全部问题（与解析层同口径）。
    final PackContent content;
    try {
      content = readPack(text, skeletonPaths: skeletonPaths);
    } on PackContentException catch (error) {
      problems.addAll(error.problems);
      return InstallResult.failed(problems);
    }

    // ③ 三元校验。**只对载荷包做**：非载荷包没有 `attach_to`，节点定位不到
    //    轴根就没有 `path` 可算 —— 那不是「校验失败」，是「没有这一元」。
    final Pack pack = content.pack;
    final Map<String, String> paths;
    if (pack.payload == null) {
      paths = const <String, String>{};
    } else {
      final JsonMap raw = jsonDecode(text) as JsonMap;
      final PathValidation validation = validatePack(raw, skeletonPaths);
      if (!validation.ok) {
        problems.add(
          '路径校验未通过：${validation.codes.join(" / ")}'
          '（`path-rules` `P-01`–`P-09`）—— 算不出 `path` 的节点装进来也定位不到',
        );
        return InstallResult.failed(problems);
      }
      paths = validation.paths;
    }

    // ④ 台账冲突。**按算出来的 `path` 全表查**，而不是只查 `path_reservations[]`：
    //    后者声明的是本包将要占用的 `(父, slug)`，与这张表重合；对着一张更全的
    //    表查，比对着声明的子集查更严，且同样是 O(n) —— 而漏查的后果是
    //    「两个包共用一个 path」，正是 `P-14` 存在要挡的那件事。
    final ClaimLedger? ledger = _readLedger(problems);
    if (ledger == null) {
      return InstallResult.failed(problems);
    }

    final Map<String, PathClaim> wanted = <String, PathClaim>{
      for (final MapEntry<String, String> entry in paths.entries)
        entry.value: PathClaim(
          path: entry.value,
          nodeId: entry.key,
          state: ClaimState.live,
        ),
    };
    for (final MapEntry<String, PathClaim> entry in wanted.entries) {
      final PathClaim? held = ledger.claimOf(entry.key);
      if (held == null || held.nodeId == entry.value.nodeId) {
        // 没占过 ⇒ 首次占用；同一个节点 ⇒ 重装（墓碑可以回到现役）。
        continue;
      }
      problems.add(
        held.isTombstone
            ? '`${entry.key}` 是 `${held.nodeId}` 的墓碑 —— 墓碑永不复用'
                  '（`P-14`）：放开它，「A 卸载 → B 装上 → A 再装回」时 A 会'
                  '以为自己是首次占用，直接覆盖 B'
            : '`${entry.key}` 已被 `${held.nodeId}` 占用 —— 两个包共用一个 `path`，'
                  '父链与面包屑会对不上',
      );
    }
    if (problems.isNotEmpty) {
      return InstallResult.failed(problems);
    }

    // ⑤ 落盘。台账不可变 ⇒ 写失败时盘上与内存里都还是旧的那份。
    //    非载荷包没有 claim 可写（`paths` 为空）—— 那就一个字节都不碰盘：
    //    「什么都没改也重写一遍」会让文件时间戳说谎。
    final ClaimLedger next = ledger.withClaims(wanted.values);
    if (wanted.isNotEmpty && !_writeLedger(next, problems)) {
      return InstallResult.failed(problems);
    }

    final InstalledPack installed = InstalledPack(
      packRoot: location.packRoot,
      content: content,
      paths: Map<String, String>.unmodifiable(paths),
      claims: List<PathClaim>.unmodifiable(wanted.values),
    );
    _installed[pack.pluginId] = installed;
    return InstallResult.ok(installed);
  }

  /// 卸载。**只转墓碑，不删条目**（`P-14`）。
  ///
  /// 认领按节点 `id` 前缀判（`{plugin_id}:`）：`validatePack` 的 `E-ID-FORMAT`
  /// 已经保证每个节点 id 都以本包 `plugin_id` 开头，所以前缀不会误伤
  /// 另一个包（前缀里带分隔符，`m2-demo` 不会命中 `m2-demo-x:`）。
  UninstallResult uninstall(String pluginId) {
    final List<String> problems = <String>[];

    final ClaimLedger? ledger = _readLedger(problems);
    if (ledger == null) {
      return UninstallResult.failed(pluginId, problems);
    }

    final String prefix = '$pluginId$idNamespaceSeparator';
    final List<PathClaim> mine = ledger.claims
        .where((PathClaim claim) => claim.nodeId.startsWith(prefix))
        .toList(growable: false);
    if (mine.isEmpty) {
      return UninstallResult.failed(pluginId, <String>[
        '未安装 `$pluginId`：台账里没有任何以 `$prefix` 开头的节点',
      ]);
    }

    int tombstoned = 0;
    ClaimLedger next = ledger;
    for (final PathClaim claim in mine) {
      if (claim.isTombstone) {
        continue;
      }
      next = next.withClaim(
        PathClaim(
          path: claim.path,
          nodeId: claim.nodeId,
          state: ClaimState.tombstone,
        ),
      );
      tombstoned++;
    }

    if (tombstoned > 0 && !_writeLedger(next, problems)) {
      return UninstallResult.failed(pluginId, problems);
    }

    _installed.remove(pluginId);
    return UninstallResult.ok(pluginId, tombstoned);
  }

  /// 读台账。**文件不存在 = 空台账**（第一次装包前的正常状态）；
  /// 文件在但读不出 / 不是合法台账 = 问题，返回 `null`。
  ClaimLedger? _readLedger(List<String> problems) {
    final String path = claimsPath;
    final String? text = storeFs.readString(path);
    if (text == null) {
      if (storeFs.isFile(path)) {
        problems.add('台账 `$path` 在但读不出来（权限 / 非 UTF-8）—— 中止，不重建');
        return null;
      }
      return ClaimLedger.empty();
    }
    try {
      return ClaimLedger.fromJson(text);
    } on FormatException catch (error) {
      problems.add('台账 `$path` 不是合法台账：${error.message}');
      return null;
    }
  }

  bool _writeLedger(ClaimLedger ledger, List<String> problems) {
    if (!storeFs.ensureDir(layout.writableRoot)) {
      problems.add('建不出可写区目录 `${layout.writableRoot}` —— 台账没写成');
      return false;
    }
    if (!storeFs.writeStringAtomic(claimsPath, ledger.toJson())) {
      problems.add('台账 `$claimsPath` 原子写失败 —— 盘上仍是旧的那份');
      return false;
    }
    return true;
  }

  String _probeProblemText(PackProblem problem) => switch (problem.kind) {
    PackProblemKind.missingPack =>
      '`${problem.path}` 不存在 —— 一个包 = 一个目录 + 一个 `pack.json`'
          '（`SPEC-PACK-018`）',
    PackProblemKind.unreadable =>
      '`${problem.path}` 在但读不出来（权限 / 非 UTF-8）',
  };
}
