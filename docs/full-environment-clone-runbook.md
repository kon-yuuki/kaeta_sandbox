# Full Environment Clone Runbook (Supabase + PowerSync)

この手順書は「既存データは移行しない」「環境設定は同一にする」前提です。  
目的は、個人アカウントの Supabase / PowerSync から、共有アカウント側に同等環境を再構築することです。

---

## 1. 事前準備

## 1-1. 必要な情報

1. 旧 Supabase の `project_ref`
2. 旧 Supabase の DB パスワード
3. 新 Supabase の `project_ref`
4. 新 Supabase の DB パスワード
5. 旧 PowerSync の設定値（Sync Rules / Upload Rules / instance URL）

## 1-2. ローカルツール

1. `pg_dump` / `psql`
2. `supabase` CLI（Functions を使っている場合）

---

## 2. Supabase 新環境の作成

1. 共有アカウントで新 Supabase プロジェクト作成
2. リージョンは旧環境と同じにする（可能なら）
3. 作成後、`Project URL` と `anon key` を控える

---

## 3. スキーマを完全コピー（データなし）

## 3-1. 旧環境から schema-only をエクスポート

```bash
pg_dump "postgresql://postgres:<OLD_DB_PASSWORD>@db.<OLD_PROJECT_REF>.supabase.co:5432/postgres" \
  --schema-only --no-owner --no-privileges \
  --schema=public --schema=storage --schema=auth \
  > supabase_schema.sql
```

## 3-2. 新環境へ適用

```bash
psql "postgresql://postgres:<NEW_DB_PASSWORD>@db.<NEW_PROJECT_REF>.supabase.co:5432/postgres" \
  -f supabase_schema.sql
```

## 3-3. 適用確認

1. 主要テーブルが存在する
2. インデックスが存在する
3. Trigger / Function が存在する
4. RLS が有効か
5. Policy が同数あるか

---

## 4. Supabase 管理画面設定をコピー

## 4-1. Auth 設定

1. `Site URL`
2. `Redirect URLs`
3. Provider 設定（Google / Apple など）
4. Email テンプレート・送信設定（使っていれば）

## 4-2. Storage 設定

1. バケット名（同名で作成）
2. Public/Private 設定
3. バケットごとの RLS policy

## 4-3. Edge Functions

1. 同じコードを新環境へ deploy
2. Secrets（環境変数）を同じ値で投入
3. Function ごとの認可設定を確認

## 4-4. Realtime

1. Realtime 対象テーブルの有効化状態を合わせる

---

## 5. PowerSync を別アカウントに複製

## 5-1. 新 PowerSync インスタンス作成

1. 共有アカウントで新インスタンス作成
2. 新 Supabase を接続先に設定

## 5-2. 旧設定を移植

1. Sync Rules を旧環境と同じ内容で反映
2. Upload Rules を旧環境と同じ内容で反映
3. 必要な認証・接続キーを設定

## 5-3. 接続確認

1. 初回同期が成功する
2. Upload queue でエラーが出ない
3. `PGRST` 系エラー（カラム不一致）が出ない

---

## 6. アプリ側の切替

## 6-1. Supabase の切替

1. `SUPABASE_URL` を新環境へ
2. `SUPABASE_ANON_KEY` を新環境へ

## 6-2. PowerSync の切替

1. `PowerSync URL` を新インスタンスへ
2. `PowerSync API Key`（使っている場合）を差し替え

## 6-3. 再インストール推奨

1. アプリ削除
2. 再インストール
3. ローカルDB再初期化を確認

---

## 7. 完了チェックリスト

1. ログインできる
2. 家族作成・参加リンクが動作する
3. アイテム追加/編集/完了が動作する
4. 画像アップロード/表示が動作する
5. 設定画面保存が動作する
6. 同期が成功し続ける（PowerSync warning なし）

---

## 8. トラブル時の確認ポイント

1. `PGRST204` が出る  
   - 新環境スキーマ不足（カラム未作成）
2. ログインはできるがデータが見えない  
   - RLS policy 差分
3. Function が動かない  
   - Secret 未設定 or URL/Key 差し替え漏れ
4. PowerSync が詰まる  
   - Sync/Upload rules の差分

---

## 9. ロールバック

1. 旧 `SUPABASE_URL` / `SUPABASE_ANON_KEY` を保存しておく
2. 旧 PowerSync 接続情報を保存しておく
3. 切替不具合時は環境変数を旧値に戻して再ビルド

