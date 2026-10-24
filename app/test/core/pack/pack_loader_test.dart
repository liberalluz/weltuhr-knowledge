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

_MemoryStore _storeWithM2() => _MemoryStore(
  files: <String, String>{'content/m2/pack.json': m2PackJson()},
);

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
      expect(ledger.claims.every((PathClaim c) => c.state == ClaimState.live), isTrue);
      expect(ledger.claimOf('major/080901/lang-core')!.nodeId, 'm2-demo:lang-core');
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
      expect(blind.files.containsKey(_claimsFile), isFalse, reason: '拒装就不该留下台账');
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
      expect(
        store.files[_claimsFile],
        taken,
        reason: '冲突时一字不写 —— 半装比不装更糟',
      );
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

    test('非载荷包照装，但一个 claim 也不写 —— 它没有 attach_to，没有 path 可占（无 SPEC：四类包里只有载荷带定位）', () {
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
    });
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
      expect(ledger.claimOf('major/080901/lang-core')!.nodeId, 'm2-demo:lang-core');
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
      expect(ledger.claims.every((PathClaim c) => c.state == ClaimState.live), isTrue);
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
      expect(
        store.files[_claimsFile],
        broken,
        reason: '原来那份坏数据原样留着，才查得出是怎么坏的',
      );
    });
  });
}
