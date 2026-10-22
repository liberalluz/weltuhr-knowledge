# Weltuhr

[English](../../README.md) · [简体中文](README.zh.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · **日本語** · [Français](README.fr.md)

> [docs/readme/README.zh.md](../../docs/readme/README.zh.md) の翻訳です · 2026-10-17 · 中国語版が正となります。

> ある学習領域を、**位置づけでき、計画でき、計量できる**知識空間へと展開します。「X を学びたい」を「何をどの順序で学べばよいか、どこまで進めば使えると言えるかが分かっている」に変えるための仕組みです。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](../../LICENSE)

## 特長

- **知識空間**：知識はコンテンツパックを単位に組織します（一空間に一パック）。空間の境界は三つの判断基準で決まり、人が手で階層に切るものではありません
- **ディレクトリではなく座標**：六軸（学科 / 職種 / 業界 / 能力 / 主題 / 技術スタック）× 三層（持続 / ビュー / 短命）が**索引座標**をなし、重ねて絞り込めます。入れ子のフォルダではありません
- **3D 宇宙 + 2D ツリー + 詳細**：同一のグラフモデルに対する三つの投影です。位置そのものが意味を持ち（`r` / `θ` / `φ`）、力学モデルによる 3D レイアウトは使いません
- **計画の三段階**：源（教材）→ 体系（順序）→ 方法（行動 + 判断基準）。三段とも自分で作れ、候補はそれぞれの根拠で並び、取捨の代償が表示されます
- **習得七段階のループ**：定位 → 計画 → 修習 → 検証 → 保持 → 出口。復習は FSRS に従います。進捗は離散（決して後退しない）、習熟は連続（下がりうる）として分離されています
- **二種類のノート**：体系ノート（体系から派生）と自作ノートが同じ `itemId` アンカーを共有し、その場で切り替えられます。外部ノートアプリへの書き出しは一方向です

## クイックスタート

> 前提：Flutter 3.x + Dart 3.x · Serverpod 4.x（バージョンは `app/pubspec.yaml` / `server/pubspec.yaml` の固定値が基準）· PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# クライアントの依存関係
cd app && flutter pub get

# サーバーの依存関係 + DB 起動
cd ../server && dart pub get

# コンテンツパックの生成（クライアント実行より先に行う：クライアントは実行時の CWD から content/<space>/dist/pack.json を探します）
cd ../content && python tools/build.py

# 実行
cd ../app && flutter run -d windows
```

## ディレクトリ構成

| ディレクトリ | 責務 |
|---|---|
| [app/](../../app/README.md) | Flutter クライアント（Windows / macOS / iOS を一つのコードで） |
| [server/](../../server/README.md) | Serverpod サーバー：同期、イベント統合、ガバナンスと審査 |
| [content/](../../content/README.md) | コンテンツパックの元データとビルドパイプライン |
| [docs/](../../docs/README.md) | 成果物ドキュメント、生きたドキュメント、ADR、設計仕様 |
| [infra/](../../infra/README.md) | ビルド / 署名 / アップデータ / ミラー / CI |

そのほか：[docs/intent/knowledge-system-learning-methodology.md](../intent/knowledge-system-learning-methodology.md) — 本プロジェクトの**方法論的な根拠**（知識体系学習の方法論）。ソフトウェア設計仕様は [docs/specs/](../specs/00-index.md) を参照してください。

## ドキュメント

- [docs/README.md](../../docs/README.md) — ドキュメント体系の索引（成果物 / 生きたドキュメント / ADR）
- [docs/specs/00-index.md](../specs/00-index.md) — **設計仕様の索引**（FND / VIEW / PACK / PLAN / STEP / QUANT / NOTE / GOV + 横断表）

## ライセンスとクレジット

Copyright (c) 2026 liberal。本プロジェクトは [Apache-2.0](../../LICENSE) ライセンスで公開しています。あわせて [NOTICE](../../NOTICE) をご覧ください。

## コントリビュートとサポート

- **セキュリティ脆弱性**：公開 issue は使わず、[.github/SECURITY.md](../../.github/SECURITY.md) に記載の非公開の窓口から報告してください（7 営業日以内に一次回答することをお約束します）
- 質問・提案：リポジトリの Issues へ。内容の誤りは空間識別子と `itemId` を明記してください
- コントリビュートの流れ：[.github/CONTRIBUTING.md](../../.github/CONTRIBUTING.md)
