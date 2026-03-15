# COMPLETED_TASKS

更新日: 2026-03-15

## 2026-03-15

| ID | 区分 | タスク | 完了日 | メモ |
|---|---|---|---|---|
| C01 | 通知 | `device_tokens` が作成/更新されるように APNs token 取得不全を修正 | 2026-03-15 | TestFlight 実機で `native_did_register_for_remote_notifications=ok` / `get_token_result=ok` / `upsert_device_tokens=ok` を確認済み |
| F09 | 通知 | 家族通知の push 送受信を自動実行込みで成立させる | 2026-03-15 | `notification_jobs` + `send-push` worker + `pg_cron` で `pending -> sent` を確認済み |
| C03 | 通知 | push 通知の疎通確認 | 2026-03-15 | 手動 worker 実行と実端末で送受信確認済み |

## 2026-02-26

| ID | 区分 | タスク | 完了日 | メモ |
|---|---|---|---|---|
| A01 | 認証 | Appleログイン失敗の詳細化 | 2026-02-26 | `SignInWithAppleAuthorizationException.message` を表示するよう修正済み |
| I02 | 招待 | 新規アカウント直後の招待リンク作成FKエラー対応 | 2026-02-26 | `families` のサーバー同期待ちを入れて `create_invite` 実行に変更 |
| U01 | UI | アイテム追加: `リストに追加する` を下部固定CTA化 | 2026-02-26 | `Scaffold.bottomNavigationBar` へ移設済み |
| U02 | UI | 候補バー位置を簡易追加と同様に調整 | 2026-02-26 | キーボード上に表示されるよう修正済み |
| U03 | UI | アイテム名入力エリアを枠線なしに変更 | 2026-02-26 | 画像なし時の入力レイアウトを更新済み |
| U04 | UI | 写真追加時に全幅画像 + 下に入力欄 | 2026-02-26 | プレビュー/削除/撮り直しUIまで反映済み |
