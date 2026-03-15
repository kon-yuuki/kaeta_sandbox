# Push Worker Status

更新日: 2026-03-15

## 現状整理

- 家族通知の producer は `public.notify_family_members` に集約済み
- RPC は `public.app_notifications` を追加したうえで `public.notification_jobs` に job を積む
- Flutter 側の `NotificationsRepository` は家族モード時に `notify_family_members` RPC を呼ぶ
- `device_tokens` / `push_debug_logs` から、対象端末のトークン同期は成功している

## 切り分け結果

- 旧案の `pg_net` による DB -> Edge Function 直呼びは不安定だった
- `net._http_response` では `Couldn't resolve host name` が再現した
- 一方で外部ホスト向け `pg_net` は `200` を返しており、一般的な egress 不可ではなかった
- そのため、配信経路は outbox パターンへ切り替えた

## 2026-03-15 時点で確認できたこと

- `notify_family_members` の定義は `app_notifications` + `notification_jobs` の producer に更新済み
- アイテム追加のたびに `notification_jobs` に `pending` 行が増えることを確認済み
- `send-push` worker は本番稼働済みで、`pg_cron` による自動実行も確認済み

## 残修正タスク

1. `partial_failure` を別 status に昇格するかは運用判断が残る

## 追加実装

- `showTopSnackBar(..., saveToHistory: true, familyId: あり)` は server-side 通知配信へ流すよう更新
- `notification_jobs` の cleanup 方針を SQL 化
- `failed` jobs は `attempts < 3` の間、自動再送対象に更新
- 監視クエリを `docs/sql/notification_jobs_monitoring.sql` に追加
- `notification_jobs.delivery_summary` と `notification_job_delivery_logs` で、全成功 / 一部成功 / 全失敗を追跡できるよう更新

## 自動実行

- scheduler 用 SQL は `docs/sql/push_worker_scheduler_setup.sql`
- vault 登録用 SQL は `docs/sql/push_worker_vault_setup.sql`
- 本番では cron から 1 分おきに `send-push` を呼ぶ

## 完了タスクの記録先

- 完了済みの通知タスクは `docs/COMPLETED_TASKS.md` に移動
- アクティブタスクは `WORK_TASK_SHEET.md` で管理

## 確認観点

1. アイテム追加で `notification_jobs` に `pending` が増える
2. worker 実行で `pending -> sent/failed` に変わる
3. 失敗時は `last_error` に理由が残る
4. 端末側で通知が届く
