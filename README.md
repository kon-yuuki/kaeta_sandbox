# kaeta_sandbox

Kaeta買い物リストアプリのフェーズ0プロトタイプ - Flutter技術検証用サンドボックス

## プロジェクト概要

このプロジェクトは、Kaeta買い物リスト・購買履歴アプリの技術検証を目的としたプロトタイプです。RiverpodとDriftを使ったFlutterアプリの基本実装を含んでいます。

## 技術スタック

- **Flutter**: ^3.8.1
- **状態管理**: Riverpod with AsyncNotifierProvider
- **ローカルDB**: Drift (SQLite) ORM
- **バックエンド連携**: Supabase + PowerSync (予定)
- **コード生成**: build_runner

## 機能

### 実装済み
- todoアイテムの基本CRUD操作
- リアルタイムUI更新 (Driftのwatchストリーム使用)
- クリーンアーキテクチャ実装
- UUIDベースのアイテム管理

### 予定
- Supabase統合とリアルタイム同期
- 購入履歴機能
- オフライン同期 (PowerSync)
- 優先度システム
- スマート提案機能

## セットアップ

### 必要条件
- Flutter SDK 3.8.1以上
- Dart SDK

### インストール

1. 依存関係のインストール:
```bash
flutter pub get
```

2. コード生成:
```bash
flutter packages pub run build_runner build
```

## 開発

### コード生成の監視
開発中は以下のコマンドで自動コード生成を有効にしてください：
```bash
flutter packages pub run build_runner watch
```

### アプリの実行
```bash
flutter run
```

### その他のコマンド
```bash
flutter analyze          # 静的解析
flutter test             # テスト実行
```

## アーキテクチャ

```
lib/
├── main.dart                    # アプリエントリポイント
├── database/                    # Driftデータベース設定
│   ├── database.dart           # DB設定
│   └── schema.dart             # テーブル定義
└── features/
    └── todo/                   # Todo機能
        ├── providers/          # Riverpodプロバイダー
        ├── repositories/       # データアクセス層
        └── views/             # UI層
```

### 主要概念
- **クリーンアーキテクチャ**: プレゼンテーション、ビジネスロジック、データ層の分離
- **依存性注入**: Riverpodプロバイダーによる管理
- **リアクティブUI**: StreamBuilderによるリアルタイム更新

## 重要な注意事項

1. **コード生成**: DriftテーブルやRiverpodプロバイダーを変更した際は必ずコード生成を実行してください
2. **Git管理**: 自動生成ファイル（*.g.dart）はgit管理対象外です
3. **開発フェーズ**: これはフェーズ0のプロトタイプです。本番環境での使用は想定していません

## 次のステップ

- Supabase統合の実装
- PowerSyncによるオフライン同期
- 購入履歴機能の追加
- UIの改善とナビゲーション実装