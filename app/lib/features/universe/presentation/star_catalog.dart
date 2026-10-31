/// Hipparcos 主表解析 —— 数据取 HEASARC 的 `heasarc_hipparcos` 转制版。
///
/// 这份表是 `ADR-0006` 决策表「背景」那一行的数据来源：真实星位、真实星等、
/// 真实色指数。段 2 用的是 `V/50`（BSC5）**9,096 颗**，它是一份亮星表、收到
/// 6.5 等左右就没了，画面上是「疏星点点」；决策表那一行写的是「9,110 颗 +
/// 程序化补到 2 万」，补的这一半是要编出来的。段 3 改成 **Hipparcos 全量
/// 118,217 颗**，一颗都不用编。
///
/// **为什么不是 CDS 的 `I/239/hip_main.dat`**：`cdsarc` 两个域（http 与 https）
/// 在开发网络下都连接超时，VizieR 的哈佛镜像只是 302 跳回 CDS。HEASARC 这份
/// 是原样分发的整表、一个字节没改，所以「原文入库」这条纪律没破 —— 破的只是
/// 「原始发布方」这一层，`content/stars/README.md` 里如实登记。
///
/// **列位置不硬编码，按 `<HEADER>` 的 `field[...]` 顺序反查**：HEASARC 改版加列
/// 时，硬编码的列号会静默错位，而错位的症状是「解析成功、所有星整体偏移」——
/// 画面上照样漂亮，只有抬头找不到北斗才暴露。段 2 吃过的亏（BSC5 的 `RA` 在
/// 第 61 列而非靠前位置）是同一个坑的另一种形态。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// 表头 `TOTAL ROWS` 声明的数据行数，与实测数据行数一致（`<END>` 标记不计）。
const int kHipparcosRowCount = 118218;

/// 缺 `vmag` 的记录数（实测 1 条）。没有星等就画不出亮度，整条跳过。
const int kHipparcosMissingMagCount = 1;

/// 可渲染星数 = [kHipparcosRowCount] − [kHipparcosMissingMagCount]。
const int kHipparcosStarCount = 118217;

/// 星表相对工作区根的位置。开发期从 `content/` 或 `../content` 取，与
/// `devPackRoots()` 同一约定 —— `flutter run` 与 `flutter test` 的 CWD 都在
/// `app/`，从仓根跑则命中前者，两条都给、先命中者优先。
const String kHipparcosRelativePath =
    'content/stars/source/heasarc_hipparcos.tdat.gz';

/// 表里我们真正用到的六个字段名。少一个就解析不了，多一个不管。
const String _fHip = 'hip_number';
const String _fRa = 'ra';
const String _fDec = 'dec';
const String _fVMag = 'vmag';
const String _fBv = 'bv_color';
const String _fSpectral = 'spect_type';

const String _markerData = '<DATA>';
const String _markerEnd = '<END>';

/// 一条恒星记录。只留渲染要用的五项。
class StarRecord {
  const StarRecord({
    required this.hip,
    required this.raDeg,
    required this.decDeg,
    required this.vMag,
    required this.bvColorIndex,
    required this.spectralType,
  });

  /// Hipparcos 编号。恒星的稳定身份，测试靠它锚定。
  final int hip;

  /// 赤经，**度**，`[0, 360)`，历元 J2000。
  ///
  /// 段 2 用的是「小时」，换源后跟着换成度 —— 这份表直接给度数，换算一次
  /// 就多一处可能算错的地方。
  final double raDeg;

  /// 赤纬，度，`[-90, 90]`，历元 J2000。
  final double decDeg;

  /// 视星等，**非空**（缺星等的记录在解析时已整条跳过）。负得越多越亮。
  final double vMag;

  /// `B−V` 色指数。负值偏蓝、正值偏红。原表有缺，缺时给 `null`。
  final double? bvColorIndex;

  /// 光谱型，如 `A0Vvar`。色指数缺失时用它兜底判色。
  final String spectralType;
}

/// 一次解析的结果。
class StarCatalog {
  const StarCatalog({
    required this.stars,
    required this.rows,
    required this.skipped,
  });

  /// 可渲染的恒星，按表内顺序（这份表按赤纬排序）。
  final List<StarRecord> stars;

  /// 数据行总数（= 可渲染 + 跳过），不含 `<END>` 标记。
  final int rows;

  /// 因缺星等或坐标越界而跳过的记录数。
  final int skipped;

  /// 表内记录总数。
  int get objects => rows;
}

/// 表头里六个字段各自落在第几列（0 起）。
class _Layout {
  const _Layout({
    required this.hip,
    required this.ra,
    required this.dec,
    required this.vMag,
    required this.bv,
    required this.spectral,
    required this.width,
  });

  final int hip;
  final int ra;
  final int dec;
  final int vMag;
  final int bv;
  final int spectral;

  /// 一行的段数下限。少于此就是残行。
  final int width;
}

/// 解析星表全文。
///
/// 缺星等或坐标越界即整条跳过 —— 宁可少一颗，不可给它安一个编出来的位置。
/// 这是「真实性原则」的落点：位置错比没有更糟，因为它看起来是对的。
///
/// 表头声明的行数与实测不等时**抛错而不是照收**：那说明文件被截断或换了格式，
/// 继续解析只会得到一张「少了几千颗但看着正常」的星空。
StarCatalog parseHipparcos(String text) {
  final List<String> lines = const LineSplitter().convert(text);

  int cursor = 0;
  int? declaredRows;
  final List<String> fields = <String>[];

  for (; cursor < lines.length; cursor++) {
    final String line = lines[cursor];
    if (line.startsWith(_markerData)) {
      cursor++;
      break;
    }
    if (line.startsWith('field[')) {
      final int close = line.indexOf(']');
      if (close > 6) {
        fields.add(line.substring(6, close));
      }
      continue;
    }
    final RegExpMatch? total = RegExp(r'TOTAL ROWS:\s*(\d+)').firstMatch(line);
    if (total != null) {
      declaredRows = int.tryParse(total.group(1)!);
    }
  }

  final _Layout layout = _layoutOf(fields);

  final List<StarRecord> stars = <StarRecord>[];
  int rows = 0;
  int skipped = 0;

  for (; cursor < lines.length; cursor++) {
    final String line = lines[cursor];
    if (line.isEmpty || line.startsWith(_markerEnd)) {
      continue;
    }
    rows++;
    final StarRecord? star = _parseRow(line, layout);
    if (star == null) {
      skipped++;
      continue;
    }
    stars.add(star);
  }

  if (declaredRows != null && declaredRows != rows) {
    throw FormatException('表头声明 $declaredRows 行，实际读到 $rows 行 —— 文件被截断或换了格式');
  }

  return StarCatalog(stars: stars, rows: rows, skipped: skipped);
}

/// 从表头的字段名顺序建列索引。缺必需字段即抛。
_Layout _layoutOf(List<String> fields) {
  int indexOf(String name) => fields.indexOf(name);

  final int hip = indexOf(_fHip);
  final int ra = indexOf(_fRa);
  final int dec = indexOf(_fDec);
  final int vMag = indexOf(_fVMag);
  for (final (String name, int at) in <(String, int)>[
    (_fHip, hip),
    (_fRa, ra),
    (_fDec, dec),
    (_fVMag, vMag),
  ]) {
    if (at < 0) {
      throw FormatException('星表缺必需字段 `$name`（表头 ${fields.length} 个字段）');
    }
  }

  final int bv = indexOf(_fBv);
  final int spectral = indexOf(_fSpectral);
  final int width =
      <int>[hip, ra, dec, vMag, bv, spectral].reduce(math.max) + 1;

  return _Layout(
    hip: hip,
    ra: ra,
    dec: dec,
    vMag: vMag,
    bv: bv,
    spectral: spectral,
    width: width,
  );
}

StarRecord? _parseRow(String line, _Layout layout) {
  // 先判长度再切：`split` 在残行上给出的段数不够，按下标取会抛。
  final List<String> parts = line.split('|');
  if (parts.length < layout.width) {
    return null;
  }

  final double? vMag = double.tryParse(parts[layout.vMag]);
  if (vMag == null) {
    return null;
  }
  final double? ra = double.tryParse(parts[layout.ra]);
  final double? dec = double.tryParse(parts[layout.dec]);
  if (ra == null || dec == null) {
    return null;
  }

  // 越界即拒：赤经 360 度、赤纬 ±90 度是球面坐标的定义域。出了这个范围说明
  // 列位置错了，继续算只会得到一个「看起来合理」的错位置。
  if (ra < 0 || ra >= 360 || dec < -90 || dec > 90) {
    return null;
  }

  return StarRecord(
    hip: int.tryParse(parts[layout.hip]) ?? 0,
    raDeg: ra,
    decDeg: dec,
    vMag: vMag,
    bvColorIndex: layout.bv < 0 ? null : double.tryParse(parts[layout.bv]),
    spectralType: layout.spectral < 0 ? '' : parts[layout.spectral].trim(),
  );
}

/// 读星表原始字节（gzip）。找不到就抛，不静默退化成「空星表」——
/// 空星空与「这台机器跑不动」在画面上分不开。
Future<Uint8List> loadHipparcosBytes({String? cwd}) async {
  final String base = cwd ?? Directory.current.path;
  final List<String> roots = <String>[base, '$base/..'];
  for (final String root in roots) {
    final File file = File('$root/$kHipparcosRelativePath');
    if (file.existsSync()) {
      return file.readAsBytes();
    }
  }
  throw FileSystemException(
    '找不到星表：试过 ${roots.map((String r) => '$r/$kHipparcosRelativePath').join(' , ')}',
    kHipparcosRelativePath,
  );
}

/// 读并解压星表，返回解析结果。
Future<StarCatalog> loadHipparcosCatalog({String? cwd}) async {
  final Uint8List bytes = await loadHipparcosBytes(cwd: cwd);
  return parseHipparcos(utf8.decode(gzip.decode(bytes)));
}
