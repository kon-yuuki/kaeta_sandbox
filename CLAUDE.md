# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際のClaude Code (claude.ai/code) 向けのガイダンスを提供します。

## プロジェクト概要

Kaetaは、リアルタイム同期機能を備えたFlutterベースの買い物リスト・購買履歴アプリです。これはフェーズ0 - 技術検証用のプロトタイプ/サンドボックスです。

**技術スタック:**
- Flutter 3.8.1+ と状態管理用Riverpod
- ローカルストレージ用Drift (SQLite) とクラウド同期用PowerSync
- 認証とバックエンドデータベース用Supabase
- build_runnerによるコード生成（Riverpod、Drift、Freezed）

## 開発コマンド

```bash
# 依存関係のインストール
flutter pub get

# コード生成（プロバイダー、スキーマ、モデル変更後は必須）
flutter packages pub run build_runner build           # 一回限り
flutter packages pub run build_runner watch           # 継続的（開発中推奨）

# アプリの実行
flutter run

# 静的解析
flutter analyze

# テストの実行
flutter test
```

**重要:** 以下を変更した後は必ずコード生成を実行してください：
- `@riverpod`アノテーション付きプロバイダー → `*.g.dart`を生成
- `schema.dart`内のDriftテーブル定義 → `database.g.dart`を生成
- Freezedモデル → `*.freezed.dart`を生成

## アーキテクチャ

```
lib/
├── main.dart                     # エントリポイント: Supabase/PowerSync初期化、認証ルーティング
├── core/
│   ├── app_config.dart          # Supabase & PowerSync認証情報
│   └── app_global.dart          # グローバル設定ホルダー
│
├── data/                        # データ層
│   ├── model/
│   │   ├── schema.dart          # PowerSyncスキーマ + Driftテーブル定義
│   │   ├── database.dart        # MyDatabaseクラス（Driftセットアップ）
│   │   └── powersync_connector.dart  # Supabase-PowerSyncブリッジ
│   │
│   ├── providers/               # Riverpodプロバイダー（依存性注入）
│   │   ├── global_provider.dart # PowerSync & MyDatabaseプロバイダー
│   │   ├── items_provider.dart  # ItemsRepositoryプロバイダー
│   │   ├── category_provider.dart
│   │   └── profiles_provider.dart
│   │
│   ├── repositories/            # ビジネスロジック & データアクセス
│   │   ├── items_repository.dart    # アイテムマスター + Yahoo API連携
│   │   ├── todo_repository.dart     # Todo CRUD（Driftジョイン使用）
│   │   ├── category_repository.dart # カテゴリ管理
│   │   └── profiles_repository.dart # ユーザープロファイル同期
│   │
│   └── services/
│       └── notification_service.dart  # ローカル通知（シングルトン）
│
└── pages/                       # UI層（機能ベースの構成）
    ├── home/                    # メイン買い物リスト画面
    │   ├── home_screen.dart
    │   ├── providers/home_provider.dart    # Todoリストストリーム、ソート、検索
    │   ├── view_models/home_view_model.dart
    │   └── widgets/             # todo_add_sheet、todo_edit_sheetなど
    │
    ├── history/                 # 購買履歴画面
    │   ├── history_screen.dart
    │   ├── providers/history_provider.dart
    │   └── view_models/history_view_model.dart
    │
    ├── login/view/login_screen.dart
    └── setting/view/setting_screen.dart
```

## 主要パターン

### 状態管理（Riverpod）
- 自動生成プロバイダー用に`@riverpod`アノテーションを使用
- ウィジェットでのリアクティブ更新に`ref.watch()`を使用
- ストリームプロバイダーがDriftの`.watch()`をラップしてリアルタイムUI更新
- リポジトリは直接インスタンス化せず、プロバイダー経由で注入

### データベース（Drift + PowerSync）
- テーブルは`lib/data/model/schema.dart`で定義
- PowerSyncスキーマが同期テーブルを定義、Driftが型安全なORMを提供
- グローバル`db`インスタンス（PowerSyncDatabase）は`main.dart`で初期化
- 複数テーブル操作にはトランザクションを使用

### データ所有権
- すべてのデータは`userId`と`familyId`でフィルタリング
- クエリパターン: `WHERE familyId IS NULL OR familyId = ?`で個人+家族データを取得
- オフラインサポートのためクライアント側でUUIDを生成

### UIウィジェット
- Riverpod連携に`ConsumerWidget`または`ConsumerStatefulWidget`を使用
- 追加/編集モーダルにはボトムシート（`showModalBottomSheet`）
- main.dartのStreamBuilderが認証状態によるルーティングを処理

## データベーススキーマ

主要テーブル:
- **Items**: 購入回数とひらがな読みを持つアイテムマスターカタログ
- **TodoItems**: 現在の買い物リスト（`itemId`でItemsを参照）
- **PurchaseHistory**: 完了アイテムのアーカイブ
- **Categories**: 買い物カテゴリ（ユーザーまたは家族スコープ）
- **Profiles**: Supabase Authと同期するユーザープロファイル

## 外部API

- **Yahoo ふりがなAPI**: 漢字のアイテム名をひらがなに変換（検索/オートコンプリート用）
- **Supabase Storage**: アイテムの画像アップロード（計画中）
