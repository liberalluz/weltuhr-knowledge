import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/bench/window_fit.dart';

/// 设窗的前提（`C-33`）在本平台**真的成立**。
///
/// 这一条守的不是「窗口设得对不对」（那要真窗口，`flutter test` 里没有），而是
/// 更早一步的**绑定**：`user32.dll` / `kernel32.dll` 里每一个符号都查得到。
///
/// 为什么值得单独立一条：`v0.80.0`–`v0.80.1` 三版代码、三次真机，一次都没设上
/// 窗口，日志分别写成「前台不是本进程的窗口？」与「枚举不到本进程的可见顶层窗口？」
/// —— 两句都是猜的。真实原因是 `GetSystemMetrics` 属 `User32.dll` 而代码从
/// `kernel32` 查，`lookupFunction` 在构造期就抛 `ArgumentError`，随后被
/// `_bind()` 的 `on Object` 吞成 `null`。整段设窗（含后加的 `EnumWindows`）
/// **一次都没执行过**，而两条日志把人分别引去查前台与查窗口可见性。
///
/// 判据的落点是「符号表能不能建起来」，所以探针只碰符号表、不碰窗口：
/// 它不会去改任何真实窗口的尺寸（`win32BindError()` 的说明写了这一条）。
void main() {
  test('TC-INF-063 Win32 符号必须全部绑得上，否则设窗静默失效（C-33）', () {
    if (!Platform.isWindows) {
      // 非 Windows 上没有可绑的符号表，判据只对设窗那一半成立。
      // ⚠️ CI 跑在 ubuntu 上 ⇒ 本用例在 CI 是空过的，它真正把关的地方是
      // Windows 本机（与将来的 Windows runner）。已在 `STD` §3.70 如实登记。
      return;
    }
    expect(
      win32BindError(),
      isNull,
      reason: '任一个符号查不到 ⇒ _Win32 构造即抛、被吞成「设不了窗口」，'
          '装置只会干等 90 秒再出一组 premiseOk=false 的读数',
    );
  });
}
