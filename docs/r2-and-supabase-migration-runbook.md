# R2 + Supabase Migration Runbook

この手順書は以下2つを対象にしています。

1. 画像ストレージを Supabase Storage から Cloudflare R2 に移行する
2. 個人Supabase環境から共有用Supabase環境に移行する

---

## 0. 結論（先に判断）

- 画像だけR2に移すのは推奨（DBはSupabaseのままでOK）
- DBまでCloudflareへ移行は不要（移行コストが大きい）
- 共有Supabaseへの移行は実施可能。ただし「既存データ移行あり/なし」で所要時間が変わる

---

## 1. 事前チェック

### 1-1. 現状依存の確認

- `SUPABASE_URL` / `SUPABASE_ANON_KEY` をどこで参照しているか
- 画像URLをDBに保存しているカラム（例: `items.image_url`）
- 画像の参照経路（公開URL直参照か、署名付きURLか）

### 1-2. 切替方式を決める

- 方式A（推奨）: 段階移行
  - 新規アップロードのみR2
  - 既存画像は順次移行
- 方式B: 一括移行
  - 一気にコピーしてURL置換

---

## 2. Cloudflare R2 への画像移行

## 2-1. R2バケット作成

- Cloudflare Dashboard > R2 > Create bucket
- バケット名例: `kaeta-images-prod`
- PublicにするかPrivateにするか決める
  - Public: 実装が簡単
  - Private + signed URL: より安全（推奨）

## 2-2. 配信用ドメインを用意

- 例: `images.kaeta-jointeam.com`
- Cloudflare側でR2 custom domainを設定

## 2-3. アップロード方式を実装

- 推奨: クライアント直接アップロードは避ける
- 次のどちらかで署名付きURLを発行
  - Supabase Edge Function
  - Cloudflare Worker

必要機能:

1. `POST /image/upload-url`（put用署名URLを返す）
2. `GET /image/view-url`（必要なら取得用署名URLを返す）

## 2-4. Flutter側変更

- 画像アップロード先をSupabase StorageからR2署名URLへ変更
- DB保存値はURL文字列（またはobject key）を保持
- 既存ロジックで `image_url` を表示

## 2-5. 既存画像の移行

- Supabase Storageからエクスポート
- R2へアップロード
- DBの `image_url` を新URLに更新
- 更新後にアプリで画像表示確認

## 2-6. 移行完了後

- Supabase Storageへの新規書き込み停止
- 監視後、不要データを削除

---

## 3. Supabaseを共有アカウントへ移行

## 3-1. 新しいSupabaseプロジェクト準備

- 共有アカウントで新規プロジェクト作成
- Extensions / Auth / Storage設定を現行に合わせる
- RLSポリシー含め同等設定を適用

## 3-2. スキーマ移行

- 現行から schema SQL をエクスポート
- 新環境に適用
- 必要なら seed を投入

最低限確認:

1. テーブル・インデックス
2. RLS policy
3. Functions / Triggers
4. Realtime設定

## 3-3. データ移行（必要なら）

- 方式A: 最小移行（マスタ系のみ）
- 方式B: 全データ移行（`pg_dump` + `pg_restore`）

注意:

- Authユーザー移行は運用方針を先に決める
  - 新規ログインし直し運用にする
  - 既存ユーザー移行を行う（難易度高）

## 3-4. アプリ切替

- `SUPABASE_URL` / `SUPABASE_ANON_KEY` を新環境へ変更
- iOS/Android/Webのビルド再作成
- テスト環境で機能確認後に本番反映

## 3-5. 検証チェックリスト

1. ログインできる
2. 家族招待リンクが動作する
3. アイテム追加/編集/完了が動く
4. 画像アップロード/表示が動く
5. RLSで他ユーザーのデータが見えない

---

## 4. 「すぐできるか」の目安

- すぐ可能（半日〜1日）
  - 新Supabaseプロジェクト作成
  - スキーマ適用
  - アプリ接続先切替
  - R2バケット作成
- 追加時間が必要（1〜3日）
  - 既存データ移行
  - 既存画像移行
  - Auth移行を厳密に行う場合

---

## 5. 推奨の実行順（最短で安全）

1. 共有Supabaseを先に作る（空でも可）
2. アプリを新Supabaseへ向ける（ステージング）
3. 画像アップロードのみ先にR2へ切替
4. 既存画像をバックグラウンド移行
5. 最終的に旧Supabase Storageを停止

---

## 6. ロールバック方針

- 切替前に必ずバックアップ
- 環境変数で旧Supabaseへ戻せる状態を維持
- 画像URL切替は段階的に行い、移行バッチを再実行可能にする

