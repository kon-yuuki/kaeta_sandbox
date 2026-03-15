# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Kaetaのプロトタイプ。オフライン対応・リアルタイム同期型Flutter買い物リストアプリ。

## 開発コマンド

```bash
flutter pub get                                          # 依存関係インストール
flutter packages pub run build_runner build              # コード生成（一回限り）
flutter packages pub run build_runner watch              # コード生成（継続的、開発中推奨）
flutter run                                              # アプリ実行
flutter analyze                                          # 静的解析
flutter test                                             # テスト実行
flutter test test/specific_test.dart                     # 単一テスト実行
```

**コード生成が必須になる変更:**
- `@riverpod`アノテーション → `*.g.dart`
- `schema.dart`のDriftテーブル定義 → `database.g.dart`
- Freezedモデル → `*.freezed.dart`

**環境設定:** `.env.local`にSupabase/PowerSync/Yahoo APIキーを配置（gitignore対象）

## アーキテクチャ

```
lib/
├── main.dart                          # エントリポイント: 初期化 + _RootGate（認証状態による画面遷移）
├── core/                              # 共通設定・ウィジェット
│   ├── app_config.dart               # Supabase & PowerSync認証情報
│   ├── app_global.dart               # グローバル設定ホルダー
│   ├── app_link_handler.dart         # ディープリンク処理（招待フロー）
│   ├── theme/                        # テーマ定義（色、タイポグラフィ）
│   └── widgets/                      # 共通UIコンポーネント
│
├── data/                              # データ層
│   ├── model/
│   │   ├── schema.dart               # PowerSyncスキーマ + Driftテーブル定義（★スキーマ変更はここ）
│   │   ├── database.dart             # MyDatabaseクラス（Driftセットアップ）
│   │   └── powersync_connector.dart  # Supabase-PowerSyncブリッジ
│   ├── providers/                    # Riverpodプロバイダー（DI層）
│   ├── repositories/                 # ビジネスロジック & データアクセス
│   └── services/                     # 外部サービス連携
│
├── domain/models/                     # 純粋なドメインモデル
│
└── pages/                             # UI層（機能ベース構成）
    ├── home/                          # メイン買い物リスト画面
    │   ├── home_screen.dart
    │   ├── providers/                # 画面固有プロバイダー（ソート、検索、フィルタ）
    │   ├── view_models/              # 表示ロジック
    │   └── widgets/                  # UI部品（todo_add_sheet, todo_list_view等）
    ├── history/                      # 購買履歴画面
    ├── onboarding/                   # オンボーディングフロー
    ├── invite/                       # 招待・家族共有フロー
    ├── login/                        # ログイン画面
    ├── start/                        # スタート画面
    ├── setting/                      # 設定画面
    ├── notifications/                # 通知画面
    └── dev/                          # 開発・デバッグ用画面
```

## 主要パターン

### 状態管理（Riverpod）
- `@riverpod`アノテーションで自動生成。`ref.watch()`でリアクティブ更新
- ストリームプロバイダーがDriftの`.watch()`をラップ → リアルタイムUI更新
- リポジトリは直接インスタンス化せず、プロバイダー経由で注入
- `ref.watch(provider.select((p) => p?.fieldId))`パターンで不要なリビルドを抑制

### データベース（Drift + PowerSync）
- テーブル定義: `lib/data/model/schema.dart`にPowerSyncスキーマ（`ps.Schema`）とDrift ORM（`@UseRowClass`付きテーブルクラス）の両方を定義
- グローバル`db`インスタンス（`PowerSyncDatabase`）は`main.dart`のトップレベル`late final`変数。リポジトリは`MyDatabase(db)`でDrift操作にアクセス
- 複数テーブル操作にはDriftトランザクションを使用
- クライアント側でUUID生成（`const Uuid().v4()`、オフライン対応のため）
- スキーマエラー時は自動でDB削除→再作成するリカバリ処理あり

### リポジトリパターン
- コンストラクタで`MyDatabase`を受け取る: `XxxRepository(this._db)`
- 読み取り系は`Stream<List<T>>`を返すwatchメソッド、書き込み系は`Future<void>`
- 全クエリを`userId`と`familyId`でフィルタリング
- 個人+家族データ取得パターン: `WHERE familyId IS NULL OR familyId = ?`

### アプリ初期化フロー（main.dart）
1. Flutter/Timezone/Firebase初期化
2. Supabase初期化（認証情報はAppConfig）
3. PowerSyncデータベース初期化（スキーマエラー時は自動リカバリ）
4. `_RootGate`: Supabase Auth状態ストリーム監視 → 認証済みならPowerSync接続 → オンボーディングまたはホーム画面

### ナビゲーション
- ルーターライブラリ未使用。標準`Navigator.push()`+ `MaterialPageRoute`
- ディープリンク: `AppLinkHandler`が`kaeta://invite/{id}`を処理

### UI
- `ConsumerWidget`/`ConsumerStatefulWidget`でRiverpod連携
- 追加/編集はボトムシート（`showModalBottomSheet`）
- ゲストユーザー（匿名認証）対応あり
- 画像はWebPに圧縮してSupabase Storageへアップロード、URLをDBに保存

## データベーススキーマ

主要テーブル（`schema.dart`で定義）:
- **Items**: アイテムマスター（購入回数、ひらがな読み、画像URL、予算、数量）
- **TodoItems**: 買い物リスト（`itemId`でItemsを参照、完了/未完了状態）
- **PurchaseHistory**: 完了アイテムアーカイブ
- **Categories**: 買い物カテゴリ（ユーザーまたは家族スコープ）
- **Profiles**: ユーザープロファイル（Supabase Auth同期、オンボーディング状態）
- **Families / FamilyMembers**: 家族/チーム情報とメンバーシップ
- **Invitations**: 招待コードと有効期限
- **FamilyBoards**: ひとこと掲示板（家族/個人）
- **AppNotifications**: アプリ内通知履歴
- **DeviceTokens**: FCMトークン管理（デバイス/プラットフォーム別）
- **MasterItems**: マスターアイテムデータ（サジェスト用）

## Supabase Edge Functions

`supabase/functions/`に配置:
- **send-push/**: FCM v1 APIでプッシュ通知送信。`notification_jobs` の worker としても動作し、`device_tokens` からトークン取得。無効トークンは自動削除
- **delete-item-images/**: Supabase Storageからアイテム画像を一括削除（family/accountスコープ）

## 外部API

- **Yahoo ふりがなAPI**: 漢字→ひらがな変換（検索/オートコンプリート用）
- **Supabase Storage**: `item_images`バケットにアイテム画像保存
