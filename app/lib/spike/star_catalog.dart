/// `V/50`（Bright Star Catalogue, 5th Revised Ed.）星表解析。
///
/// 这份星表是 `ADR-0006` 决策表「背景」那一行的数据来源：真实星位、真实星等、
/// 真实色指数。它代替了笔 1 里用 `Random(20261030)` 撒出来的占位星 —— 那批
/// 星看着像夜空，但抬头找不到北斗，因为每颗的位置都是随机数。
///
/// **字段偏移照 `bsc5.readme` 的字节表取，不靠样例反推**：这份文件的 `RA` 在
/// 第 61 列而不是常识里的靠前位置，因为前面依次是 `HR` / `Name` / `DM` /
/// `HD` / `SAO` / `FK5` / `IRflag` / `Multiple` / `ADS` / `VarID` 十段。
/// 另行文里有两组坐标（B1900 与 J2000），**只用 J2000**。
///
/// `V/50` 全表 **9,110 个对象**，其中 **14 个是保留编号的客星与河外星系**
/// （1908 年初版就在册，为保号不删），它们的坐标为空 ⇒ 解析时跳过，
/// 剩下 **9,096 颗恒星**。这个 9,110 → 9,096 的差额是数据本身的性质，
/// 不是解析缺陷，所以 [StarCatalog.skipped] 单独计数而不是静默丢弃。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// `V/50` 全表对象数。
const int kBsc5ObjectCount = 9110;

/// 全表中坐标完整的恒星数（= 对象数 − 14 个无坐标对象）。
const int kBsc5StarCount = 9096;

/// 星表相对工作区根的位置。开发期从 `content/` 或 `../content` 取，与
/// `devPackRoots()` 同一约定 —— `flutter run` 与 `flutter test` 的 CWD 都在
/// `app/`，从仓根跑则命中前者，两条都给、先命中者优先。
const String kBsc5RelativePath = 'content/stars/source/bsc5.dat.gz';

/// 定宽字段的列区间（1 起、闭区间），照 `bsc5.readme`。
class _Col {
  static const List<int> hr = <int>[1, 4];
  static const List<int> raHour = <int>[76, 77];
  static const List<int> raMinute = <int>[78, 79];
  static const List<int> raSecond = <int>[80, 83];
  static const List<int> decSign = <int>[84, 84];
  static const List<int> decDegree = <int>[85, 86];
  static const List<int> decMinute = <int>[87, 88];
  static const List<int> decSecond = <int>[89, 90];
  static const List<int> vMag = <int>[103, 107];
  static const List<int> bv = <int>[110, 114];
  static const List<int> spectralType = <int>[128, 147];
}

/// 一条恒星记录。只保留渲染用得上的四项，外加编号与光谱型（后者给颜色兜底）。
class StarRecord {
  const StarRecord({
    required this.hr,
    required this.raHours,
    required this.decDeg,
    required this.vMag,
    required this.bvColorIndex,
    required this.spectralType,
  });

  /// 哈佛修订号（1–9,110）。恒星的稳定身份，测试靠它锚定。
  final int hr;

  /// 赤经，小时，`[0, 24)`，历元 J2000。
  final double raHours;

  /// 赤纬，度，`[-90, 90]`，历元 J2000。
  final double decDeg;

  /// 视星等。越小越亮；天空里最亮的天狼星是 −1.46。
  final double? vMag;

  /// `B−V` 色指数。负值偏蓝、正值偏红。原表有缺，缺时给 `null`。
  final double? bvColorIndex;

  /// 光谱型，如 `A1V`。色指数缺失时用它兜底判色。
  final String spectralType;
}

/// 一次解析的结果。
class StarCatalog {
  const StarCatalog({required this.stars, required this.skipped});

  /// 坐标完整的恒星，按表内顺序。
  final List<StarRecord> stars;

  /// 因坐标为空而跳过的对象数。`V/50` 里恒为 14。
  final int skipped;

  /// 表内对象总数（恒星 + 跳过）。
  int get objects => stars.length + skipped;
}

/// 解析星表全文。
///
/// 坐标缺任何一段即整条跳过 —— 宁可少一颗，不可给它安一个编出来的位置。
/// 这是「真实性原则」的落点：位置错比没有更糟，因为它看起来是对的。
StarCatalog parseBsc5(String text) {
  final List<StarRecord> stars = <StarRecord>[];
  int skipped = 0;
  for (final String raw in const LineSplitter().convert(text)) {
    if (raw.trim().isEmpty) {
      continue;
    }
    final StarRecord? star = _parseRecord(raw);
    if (star == null) {
      skipped++;
      continue;
    }
    stars.add(star);
  }
  return StarCatalog(stars: stars, skipped: skipped);
}

StarRecord? _parseRecord(String line) {
  // 短行补空格：定宽切片越界会抛，而尾部的空字段本来就是「缺」。
  final String record = line.padRight(160);

  final int? raHour = _readInt(record, _Col.raHour);
  final int? raMinute = _readInt(record, _Col.raMinute);
  final double? raSecond = _readDouble(record, _Col.raSecond);
  final int? decDegree = _readInt(record, _Col.decDegree);
  final int? decMinute = _readInt(record, _Col.decMinute);
  final int? decSecond = _readInt(record, _Col.decSecond);
  if (raHour == null ||
      raMinute == null ||
      raSecond == null ||
      decDegree == null ||
      decMinute == null ||
      decSecond == null) {
    return null;
  }

  final String sign = _slice(record, _Col.decSign);
  final double raHours = raHour + raMinute / 60 + raSecond / 3600;
  final double decMagnitude = decDegree + decMinute / 60 + decSecond / 3600;
  final double decDeg = sign == '-' ? -decMagnitude : decMagnitude;

  // 越界即拒：赤经 24 小时、赤纬 ±90 度是球面坐标的定义域，出了这个范围
  // 说明列切错了，继续算只会得到一个「看起来合理」的错位置。
  if (raHours < 0 || raHours >= 24 || decDeg < -90 || decDeg > 90) {
    return null;
  }

  return StarRecord(
    hr: _readInt(record, _Col.hr) ?? 0,
    raHours: raHours,
    decDeg: decDeg,
    vMag: _readDouble(record, _Col.vMag),
    bvColorIndex: _readDouble(record, _Col.bv),
    spectralType: _slice(record, _Col.spectralType).trim(),
  );
}

/// 取 1 起闭区间的列。
String _slice(String line, List<int> cols) =>
    line.substring(cols[0] - 1, cols[1]);

int? _readInt(String line, List<int> cols) => int.tryParse(_slice(line, cols));

double? _readDouble(String line, List<int> cols) =>
    double.tryParse(_slice(line, cols));

/// 读星表原始字节（gzip）。找不到就抛，不静默退化成「空星表」——
/// 空星空与「这台机器跑不动」在画面上分不开。
Future<Uint8List> loadBsc5Bytes({String? cwd}) async {
  final String base = cwd ?? Directory.current.path;
  final List<String> roots = <String>[base, '$base/..'];
  for (final String root in roots) {
    final File file = File('$root/$kBsc5RelativePath');
    if (file.existsSync()) {
      return file.readAsBytes();
    }
  }
  throw FileSystemException(
    '找不到星表：试过 ${roots.map((String r) => '$r/$kBsc5RelativePath').join(' , ')}',
    kBsc5RelativePath,
  );
}

/// 读并解压星表，返回解析结果。
Future<StarCatalog> loadBsc5Catalog({String? cwd}) async {
  final Uint8List bytes = await loadBsc5Bytes(cwd: cwd);
  return parseBsc5(utf8.decode(gzip.decode(bytes)));
}
