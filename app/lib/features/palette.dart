/// 视图层共用的颜色。**只在 `features/` 用** —— 核心层不认颜色（`R1`），
/// 视觉通道的取色仍由 `channel-table.md` 定、由 `frame_painter.dart` 落。
///
/// 为什么单开一个文件：宇宙与详情是同一块画布上的两层，各写一份色值以后必然
/// 走偏（面板底色差一档，切换时能看见闪一下）。
library;

import 'package:flutter/material.dart';

/// 画布底色。
const Color paletteBackground = Color(0xFF0B0D12);

/// 浮层面板（半透明，让底下的星图透一点出来）。
const Color palettePanel = Color(0xE6181C26);

/// 正文字色。
const Color paletteTextPrimary = Color(0xFFE6EAF2);

/// 次要字色 / 未选中态。
const Color paletteTextSecondary = Color(0xFF8D96A8);

/// 选中态底色。
const Color paletteSelected = Color(0xFF2E3648);

/// 主题强调色（与包下发的 `accent` 同族，先给一个默认）。
const Color paletteAccent = Color(0xFF534AB7);

/// 缺口 / 未声明 —— 需要「这里少东西」的地方用它。
const Color paletteGap = Color(0xFFC9A227);

/// 虚线与分隔线。
const Color paletteLine = Color(0xFF39415A);
