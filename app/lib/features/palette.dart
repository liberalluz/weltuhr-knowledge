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

/// 三条容器轴的颜色（`B17b` 笔 3）。整幅宇宙视图取当前节点所在轴的那一色。
///
/// 三个色相在黑底上要**两两分得开**，且都不能抢走星点的白 —— 星空是背景，
/// 轴色是「你在哪条轴」这一层信息。选青 / 紫 / 金这组三分色的理由是同亮度下
/// 色相间隔最均匀；饱和度压到 0.5 上下，避免在深色背景上发光过曝而看不出形状。
///
/// ⚠️ **不进 `core/constants.dart`**：核心层不认颜色（`R1`）。常量表登记的是
/// 「有多大、多少度」这类可复算的量，色值不是。
const Color paletteAxisDiscipline = Color(0xFF5BC8D8);

/// 专业轴的颜色。
const Color paletteAxisMajor = Color(0xFF8E7BFF);

/// 角色轴的颜色。
const Color paletteAxisOccupation = Color(0xFFE0A34A);
