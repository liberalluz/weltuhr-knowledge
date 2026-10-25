[English](README.md) · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · **日本語** · [Français](README.fr.md)

> ルートの [README.md](README.md) @ d888a44 が正です。本訳はその版に対応します。

# Weltuhr

> ある学習領域を、**位置づけでき、計画でき、計量できる**知識空間へと展開します。「X を学びたい」を「何をどの順序で学べばよいか、どこまで進めば使えると言えるかが分かっている」に変えるための仕組みです。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

- **知識空間**：知識はコンテンツパックを単位に組織します（一空間に一パック）。空間の境界は三つの判断基準で決まり、人が手で階層に切るものではありません
- **一つのグラフ、三つの投影**：六軸（学科 / 職種 / 業界 / 能力 / 主題 / 技術スタック）× 三層（持続 / ビュー / 短命）が**索引座標**をなし、フィルタとして重ねられます。入れ子のフォルダではありません。3D 宇宙・2D ツリー・詳細パネルは同一グラフの三つの投影であり、位置そのものが意味を持ちます（`r` / `θ` / `φ`）。力学モデルによる 3D レイアウトは使いません
- **計画の三段階**：源（教材）→ 体系（順序）→ 方法（行動 + 判断基準）。三段とも自分で作れ、候補はそれぞれの根拠で並び、取捨の代償が表示されます
- **習得七段階のループ**：源を選ぶ → 体系を選ぶ → 方法を選ぶ → 修習 → 検証 → 保持 → 出口。復習は FSRS に従います。進捗は離散（決して後退しない）、習熟は連続（下がりうる）として分離されています
- **二種類のノート**：体系ノート（体系から派生）と自作ノートが同じ `itemId` アンカーを共有し、その場で切り替えられます。外部ノートアプリへの書き出しは一方向です

## クイックスタート

> 前提：Flutter 3.x + Dart 3.x · Serverpod 4.x（バージョンは `app/pubspec.yaml` / `server/pubspec.yaml` の固定値が基準）· PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# リポジトリ管理のフックを有効にする（コミットメッセージの形式チェック）。
# クローンごとに一度だけ。設定しなくても同じ規則は CI で走りますが、
# 気づくのは push した後になります。
git config core.hooksPath .githooks

# クライアントの依存関係
cd app && flutter pub get

# サーバーの依存関係 + DB
cd ../server && dart pub get

# コンテンツパックの生成（生成物はリポジトリに含めない；クライアントは実行時の CWD から <候補ルート>/<パックディレクトリ>/pack.json を探します）
cd ../content && python tools/build.py

# 実行
cd ../app && flutter run -d windows
```

## コマンド

| コマンド | 何をするか |
|---|---|
| `cd app && flutter run -d windows` | クライアントを起動する |
| `cd app && flutter test --reporter compact` | クライアントのテストスイートを実行する |
| `python content/tools/assemble_pack.py` | `<space>/pack.json` を組み立てる（**クライアントが読むのはこちら**） |
| `python content/tools/build.py` | 旧五段の成果物を `<space>/dist/` に出力（`verify.py` の fixture 用に移行期だけ残す） |
| `python content/tools/verify.py --suite` | コンテンツパックをスキーマに照らして検証する |
| `cd app && flutter analyze && dart run tool/lint/check.dart && dart run tool/docs/check.dart` | 静的チェック：アナライザー、リポジトリの lint 規則、ドキュメントのリンクと整合性 |

> この表は CI が実際に検査している内容と一致している必要があります。ワークフローを変えるときは、同じプルリクエストでこの表も変えます。

## プロジェクト構成

| ディレクトリ | 責務 |
|---|---|
| [app/](app/README.md) | Flutter クライアント（Windows / macOS / iOS を一つのコードで） |
| [server/](server/README.md) | Serverpod サーバー：同期、イベント統合、ガバナンスと審査 |
| [content/](content/README.md) | コンテンツパックの元データとビルドパイプライン |
| [docs/](docs/README.md) | 技術ドキュメント — 置き場所の規則は [docs/README.md](docs/README.md) |
| [infra/](infra/README.md) | ビルド / 署名 / アップデータ / ミラー / CI |

## アーキテクチャ

三層です。Flutter クライアントは一つのグラフモデルの三つの投影（3D 宇宙 / 2D ツリー / 詳細）を描画します。Serverpod サーバーが同期、イベント統合、ガバナンスと審査を担います。コンテンツパックは純粋なデータで、`content/tools/` が `pack.json` にコンパイルします。グラフモデルとその座標、パスの規則は[設計仕様の索引](docs/specs/00-index.md)にあります。

設計上の意思決定と、採らなかった代替案：[docs/decisions/](docs/decisions/)。

## ドキュメント

- 置き場所の規則と知識領域の網羅範囲：[docs/README.md](docs/README.md)
- 仕様とインターフェース契約：[docs/specs/](docs/specs/00-index.md)
- 運用、環境準備、実行のしかた：[docs/runbooks/](docs/runbooks/)
- 本プロジェクトの方法論的な根拠：[docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md)

## サポート

- まずドキュメントの索引へ：[docs/README.md](docs/README.md)
- 壊れている、起動しない：[docs/runbooks/](docs/runbooks/)
- 質問・提案：リポジトリの Issues へ。内容の誤りは空間識別子と `itemId` を明記してください

## コントリビュート

ブランチ名、コミットの形式、プルリクエスト、レビューのしきい値は [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) にあります。

メンテナー：liberal

## セキュリティ

脆弱性は [.github/SECURITY.md](.github/SECURITY.md) に記載の非公開の窓口から報告してください。セキュリティの問題で公開 issue を立てないでください。

## ライセンス

Apache-2.0 — [LICENSE](LICENSE) と [NOTICE](NOTICE) をご覧ください。
