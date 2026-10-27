import 'package:flutter_test/flutter_test.dart';
import 'package:project_knowledge/core/entities/path_claims.dart';
import 'package:project_knowledge/core/enums.dart';
import 'package:project_knowledge/core/pack/pack_fs.dart';
import 'package:project_knowledge/core/pack/pack_loader.dart';
import 'package:project_knowledge/core/pack/pack_probe.dart';
import 'package:project_knowledge/core/storage/claim_ledger.dart';
import 'package:project_knowledge/core/storage/store_fs.dart';
import 'package:project_knowledge/core/storage/store_layout.dart';

import '../../support/kind_packs.dart';
import '../../support/m2_pack.dart';

/// 内存文件系统。**同时实现两个区的接口**（只读 `PackFs` / 可写 `WritableStoreFs`）
/// —— 本组要验的是「该不该写账」，不是「原子写怎么写下去」（那是 `store_fs_test`）。
class _MemoryStore implements PackFs, WritableStoreFs {
  _MemoryStore({Map<String, String>? files})
    : files = <String, String>{...?files};

  final Map<String, String> files;

  /// 置 `true` 模拟「原子写失败」。
  bool failWrite = false;

  @override
  bool isFile(String path) => files.containsKey(path);

  @override
  List<String> listDirs(String path) {
    final Set<String> names = <String>{};
    for (final String file in files.keys) {
      if (file.startsWith('$path/')) {
        final String rest = file.substring(path.length + 1);
        final int cut = rest.indexOf('/');
        if (cut > 0) {
          names.add(rest.substring(0, cut));
        }
      }
    }
    return names.toList();
  }

  @override
  String? readString(String path) => files[path];

  @override
  bool ensureDir(String path) => true;

  @override
  bool writeStringAtomic(String path, String content) {
    if (failWrite) {
      return false;
    }
    files[path] = content;
    return true;
  }
}

const String _readOnlyRoot = 'content';
const String _writableRoot = 'data';
const String _eventRoot = 'events';
const String _claimsFile = 'data/claims.json';

/// 骨架父的 `path` 注入表（`minimal-pack` §4.2）。**不给它，载荷包的 `path`
/// 就算不出来** —— 那正是「装包必须注入骨架 path」的判据。
const Map<String, String> _skeletonPaths = <String, String>{
  'skeleton:major/080901': 'major/080901',
};

const PackLocation _m2 = PackLocation(
  kind: PackKind.payload,
  packRoot: 'content/m2',
);

const PackLocation _m3 = PackLocation(
  kind: PackKind.overlay,
  packRoot: 'content/m3',
);

/// 地形包落点。**边指向 M2 的节点** —— 端点分属两个包，单包视角看不见环。
const PackLocation _m4 = PackLocation(
  kind: PackKind.terrain,
  packRoot: 'content/m4',
);

/// M2 已装 + 一个地形变体待装的那个 store。
///
/// 变体的原文由 [`m4VariantJson`] 现算（`edge_counts` 跟着边集走），所以用例
/// 只表达「地形边怎么摆」，不会因为手写摘要而与实扫不符。
_MemoryStore _storeWithTerrainVariant({
  required List<({String from, String to, EdgeStrength strength})> edges,
}) => _storeWithM2()
  ..files['content/m4/pack.json'] = m4VariantJson(
    pluginId: 'm4-terrain',
    edges: edges,
  );

StoreLayout _layout() => StoreLayout(
  readOnlyRoot: _readOnlyRoot,
  writableRoot: _writableRoot,
  eventRoot: _eventRoot,
);

PackLoader _loader(_MemoryStore store, {Map<String, String>? skeletonPaths}) =>
    PackLoader(
      layout: _layout(),
      packFs: store,
      storeFs: store,
      skeletonPaths: skeletonPaths ?? _skeletonPaths,
    );

_MemoryStore _storeWithM2() =>
    _MemoryStore(files: <String, String>{'content/m2/pack.json': m2PackJson()});

ClaimLedger _ledgerIn(_MemoryStore store) =>
    ClaimLedger.fromJson(store.files[_claimsFile]!);

void main() {
  group('PackLoader（装）', () {
    test('装一个载荷包：每个节点各占一条 path、状态 live（无 SPEC：`path-rules` P-14）', () {
      final _MemoryStore store = _storeWithM2();

      final InstallResult result = _loader(store).install(_m2);

      expect(result.problems, isEmpty);
      expect(result.installed, isNotNull);

      final ClaimLedger ledger = _ledgerIn(store);
      expect(ledger.length, 9, reason: 'M2 有 9 个节点，一个不落');
      expect(
        ledger.claims.every((PathClaim c) => c.state == ClaimState.live),
        isTrue,
      );
      expect(
        ledger.claimOf('major/080901/lang-core')!.nodeId,
        'm2-demo:lang-core',
      );
    });

    test('骨架 path 注入后跨包 pathOf 可达，不注入则以 E-PATH-PARENT 拒装（无 SPEC：`minimal-pack` §4.2）', () {
      final _MemoryStore injected = _storeWithM2();
      final InstallResult ok = _loader(injected).install(_m2);
      expect(ok.installed!.pathOf('m2-demo:var'), 'major/080901/lang-core/var');

      // 同一份包，只是不告诉它骨架在哪：父链到骨架父就断，`path` 算不出来。
      final _MemoryStore blind = _storeWithM2();
      final InstallResult rejected = _loader(
        blind,
        skeletonPaths: const <String, String>{},
      ).install(_m2);

      expect(rejected.ok, isFalse);
      expect(rejected.problems.join('\n'), contains('E-PATH-PARENT'));
      expect(
        blind.files.containsKey(_claimsFile),
        isFalse,
        reason: '拒装就不该留下台账',
      );
    });

    test('同一 path 已被别的节点占用即拒装，台账原样不动（无 SPEC：`path-rules` P-16）', () {
      const String taken =
          '{"schema":1,"claims":['
          '{"path":"major/080901/lang-core","node_id":"other:lang-core","state":"live"}]}';
      final _MemoryStore store = _storeWithM2();
      store.files[_claimsFile] = taken;

      final InstallResult result = _loader(store).install(_m2);

      expect(result.ok, isFalse);
      expect(result.problems.join('\n'), contains('已被 `other:lang-core` 占用'));
      expect(store.files[_claimsFile], taken, reason: '冲突时一字不写 —— 半装比不装更糟');
    });

    test('同一 path 只有墓碑也拒装 —— 墓碑永不复用（无 SPEC：`path-rules` P-14）', () {
      // 这正是「A 卸载 → B 装上 → A 再装回」的第一个入口：墓碑放开，
      // B 就会以为这地址是空的。
      const String tombstoned =
          '{"schema":1,"claims":['
          '{"path":"major/080901/lang-core","node_id":"other:lang-core","state":"tombstone"}]}';
      final _MemoryStore store = _storeWithM2();
      store.files[_claimsFile] = tombstoned;

      final InstallResult result = _loader(store).install(_m2);

      expect(result.ok, isFalse);
      expect(result.problems.join('\n'), contains('墓碑永不复用'));
      expect(store.files[_claimsFile], tombstoned);
    });

    test('台账原子写失败即报，且内存里也没有这个包（无 SPEC：写失败不能算装成功）', () {
      final _MemoryStore store = _storeWithM2();
      store.failWrite = true;
      final PackLoader loader = _loader(store);

      final InstallResult result = loader.install(_m2);

      expect(result.ok, isFalse);
      expect(result.problems.join('\n'), contains('原子写失败'));
      expect(loader.installedOf('m2-demo'), isNull);
      expect(store.files.containsKey(_claimsFile), isFalse);
    });

    test(
      '非载荷包照装，但一个 claim 也不写 —— 它没有 attach_to，没有 path 可占（无 SPEC：四类包里只有载荷带定位）',
      () {
        final _MemoryStore store = _MemoryStore(
          files: <String, String>{'content/m3/pack.json': m3PackJson()},
        );

        final InstallResult result = _loader(store).install(_m3);

        expect(result.problems, isEmpty);
        expect(result.installed!.paths, isEmpty);
        expect(result.installed!.attachTo, isNull);
        expect(
          store.files.containsKey(_claimsFile),
          isFalse,
          reason: '没有 claim 可写就不碰盘，否则文件时间戳会说谎',
        );
      },
    );
  });

  group('PackLoader（卸）', () {
    test('卸载把 claim 转墓碑、不删条目（无 SPEC：`path-rules` P-14）', () {
      final _MemoryStore store = _storeWithM2();
      final PackLoader loader = _loader(store);
      expect(loader.install(_m2).ok, isTrue);

      final UninstallResult result = loader.uninstall('m2-demo');

      expect(result.problems, isEmpty);
      expect(result.tombstoned, 9);

      final ClaimLedger ledger = _ledgerIn(store);
      expect(ledger.length, 9, reason: '删了条目，「A 卸 → B 装 → A 装回」就没人挡得住');
      expect(ledger.claims.every((PathClaim c) => c.isTombstone), isTrue);
      expect(
        ledger.claimOf('major/080901/lang-core')!.nodeId,
        'm2-demo:lang-core',
      );
      expect(loader.installedOf('m2-demo'), isNull);
    });

    test('卸载后重装同一个包：自己的墓碑回到 live（无 SPEC：墓碑挡别人，不挡自己重装）', () {
      final _MemoryStore store = _storeWithM2();
      final PackLoader loader = _loader(store);
      expect(loader.install(_m2).ok, isTrue);
      expect(loader.uninstall('m2-demo').ok, isTrue);

      final InstallResult again = loader.install(_m2);

      expect(again.problems, isEmpty);
      final ClaimLedger ledger = _ledgerIn(store);
      expect(ledger.length, 9, reason: '重装是复活，不是新增');
      expect(
        ledger.claims.every((PathClaim c) => c.state == ClaimState.live),
        isTrue,
      );
    });

    test('未安装就卸载即报，且不凭空造一份台账（无 SPEC：空台账写盘会让「没装过」与「装空了」看不出区别）', () {
      final _MemoryStore store = _storeWithM2();

      final UninstallResult result = _loader(store).uninstall('m2-demo');

      expect(result.ok, isFalse);
      expect(result.problems.join('\n'), contains('未安装 `m2-demo`'));
      expect(store.files.containsKey(_claimsFile), isFalse);
    });
  });

  group('PackLoader（台账坏数据）', () {
    test('台账不是合法 JSON 即拒装，且不覆盖它（无 SPEC：坏台账不能靠重建掩盖）', () {
      const String broken = '{"schema":1,"claims":[';
      final _MemoryStore store = _storeWithM2();
      store.files[_claimsFile] = broken;

      final InstallResult result = _loader(store).install(_m2);

      expect(result.ok, isFalse);
      expect(result.problems.join('\n'), contains('不是合法台账'));
      expect(store.files[_claimsFile], broken, reason: '原来那份坏数据原样留着，才查得出是怎么坏的');
    });
  });

  group('PackLoader（跨包环）', () {
    test('TC-FND-023 地形边与已装载荷包的必学链成环即拒装，台账一个字节都不动（SPEC-FND-005）', () {
      // M2 自带 `var → func → closure`（两条都是必学）；地形包补 `closure → var`。
      // 从 M2 看只有前两条、从地形包看只有第三条 —— 单包都判不出，合图才成环。
      //
      // 反证（2026-10-27 实跑）：删掉 `install` 里那段跨包环判定 ⇒ 本条与 `024`
      // 一起变红（`Expected: false` / `Actual: <true>`），`025` / `026` 仍绿。
      final _MemoryStore store = _storeWithTerrainVariant(
        edges: <({String from, String to, EdgeStrength strength})>[
          (
            from: 'm2-demo:closure',
            to: 'm2-demo:var',
            strength: EdgeStrength.required,
          ),
        ],
      );
      final PackLoader loader = _loader(store);
      expect(loader.install(_m2).ok, isTrue, reason: '先装 M2 才有「已装」一侧');
      final String ledgerBefore = store.files[_claimsFile]!;

      final InstallResult result = loader.install(_m4);

      expect(result.ok, isFalse);
      final String problems = result.problems.join('\n');
      expect(problems, contains('跨包 `⪯` 成环'));
      expect(problems, contains('m2-demo:var'), reason: '环上节点要写全，读的人才不用自己拼');
      expect(loader.installedOf('m4-terrain'), isNull);
      expect(store.files[_claimsFile], ledgerBefore, reason: '拒装即一个字节都不写');
    });

    test('TC-FND-024 强弱混合成环同样拒装 —— 环检测不收窄到 `required`（SPEC-FND-005）', () {
      // `var → func → closure` 是必学链，地形包补的 `module ⇢ var` 是建议边。
      // 若环检测只拿 `requiredEdgesOf` 去判，这条建议边不进图 ⇒ 不成环 ⇒ 本条变绿。
      //
      // 反证（2026-10-27 实跑）：把 `TerrainGraph.cycles` 的输入换成 `requiredEdges`
      // ⇒ **只有本条红**，`023`（全必学环）仍绿 —— 两条各盖一个分支。
      final _MemoryStore store = _storeWithTerrainVariant(
        edges: <({String from, String to, EdgeStrength strength})>[
          (
            from: 'm2-demo:module',
            to: 'm2-demo:var',
            strength: EdgeStrength.recommended,
          ),
        ],
      );
      final PackLoader loader = _loader(store);
      expect(loader.install(_m2).ok, isTrue);

      final InstallResult result = loader.install(_m4);

      expect(result.ok, isFalse);
      final String problems = result.problems.join('\n');
      expect(problems, contains('跨包 `⪯` 成环'));
      expect(
        problems,
        contains('m2-demo:module'),
        reason: '环上那个 `module` 只因建议边才在环里 —— 它在报文里即证明两类边都进了图',
      );
    });

    test(
      'TC-FND-025 不构成环的地形边照装，且仍然一条 claim 也不写（无 SPEC：ADR-0005 决策 4 的包形态）',
      () {
        final _MemoryStore store = _storeWithTerrainVariant(
          edges: <({String from, String to, EdgeStrength strength})>[
            (
              from: 'm2-demo:refactor',
              to: 'm2-demo:typing',
              strength: EdgeStrength.required,
            ),
          ],
        );
        final PackLoader loader = _loader(store);
        expect(loader.install(_m2).ok, isTrue);
        final String ledgerBefore = store.files[_claimsFile]!;

        final InstallResult result = loader.install(_m4);

        expect(result.problems, isEmpty);
        expect(result.installed, isNotNull);
        expect(loader.installedOf('m4-terrain'), isNotNull);
        expect(
          store.files[_claimsFile],
          ledgerBefore,
          reason: '地形包没有 `attach_to`，没有 `path` 可占 —— 不该借「装成功」顺手重写台账',
        );
      },
    );

    test('TC-FND-026 包内环仍由解析层报「出现环」，装载层不再重复报跨包（SPEC-FND-005）', () {
      final _MemoryStore store = _storeWithTerrainVariant(
        edges: <({String from, String to, EdgeStrength strength})>[
          (
            from: 'm2-demo:closure',
            to: 'm2-demo:refactor',
            strength: EdgeStrength.required,
          ),
          (
            from: 'm2-demo:refactor',
            to: 'm2-demo:closure',
            strength: EdgeStrength.required,
          ),
        ],
      );

      final InstallResult result = _loader(store).install(_m4);

      expect(result.ok, isFalse);
      final String problems = result.problems.join('\n');
      expect(problems, contains('出现环'), reason: '一条边两端都在本包，解析层就该拒');
      expect(
        problems,
        isNot(contains('跨包 `⪯` 成环')),
        reason: '两条判据各报各的形态，同一件事不报两遍',
      );
    });
  });
}
