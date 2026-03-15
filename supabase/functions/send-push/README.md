# send-push (Supabase Edge Function)

`device_tokens` に保存されたFCMトークンへ通知送信する関数です。  
2026-03-15 時点では、単発送信に加えて `notification_jobs` を処理する worker としても使います。

## Required secrets

Supabase Project > Edge Functions > Secrets に以下を登録:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: FirebaseサービスアカウントJSON全文
- `FIREBASE_PROJECT_ID`: 例 `kaeta-42f9d`

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` はEdge Runtime既定の環境変数を利用します。

## Deploy

```bash
cd kaeta_sandbox
supabase functions deploy send-push
```

## Invoke (manual send example)

```bash
curl -i \
  -X POST 'https://fkkvqxbzvysimylzedus.supabase.co/functions/v1/send-push' \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H 'Content-Type: application/json' \
  --data '{
    "user_id":"<target-user-uuid>",
    "title":"テスト通知",
    "body":"FCMテストです",
    "data":{"screen":"notifications"}
  }'
```

## Invoke (process pending jobs)

```bash
curl -i \
  -X POST 'https://fkkvqxbzvysimylzedus.supabase.co/functions/v1/send-push' \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H 'Content-Type: application/json' \
  --data '{
    "mode":"process_pending",
    "batch_size":20
  }'
```

`--body` なしで呼ぶ場合も `pending` jobs の処理モードになります。

## Response

- `sent`: 送信成功件数
- `failed`: 送信失敗件数
- `deleted`: 失効トークン削除件数

worker モードでは以下を返します。

- `requested`: 取得した `pending` job 件数
- `claimed`: 実際に処理開始できた件数
- `sent_jobs`: `sent` に更新した job 件数
- `failed_jobs`: `failed` に更新した job 件数

## Delivery Semantics

- `notification_jobs` は受信者ユーザー単位の job
- そのユーザーの全有効トークン送信成功時のみ `status = sent`
- 1件でも失敗したら `status = failed`
- ただし一部成功 / 一部失敗の内訳は以下に残る
  - `notification_jobs.delivery_summary`
  - `notification_job_delivery_logs`

## Production

自動実行は `pg_cron` + `pg_net` で設定します。

- Vault 登録: [`docs/sql/push_worker_vault_setup.sql`](/Users/kon/private-develop/wip/Kaeta/kaeta_sandbox/docs/sql/push_worker_vault_setup.sql)
- Scheduler 設定: [`docs/sql/push_worker_scheduler_setup.sql`](/Users/kon/private-develop/wip/Kaeta/kaeta_sandbox/docs/sql/push_worker_scheduler_setup.sql)
- 配送ログ設定: [`docs/sql/notification_delivery_logs_setup.sql`](/Users/kon/private-develop/wip/Kaeta/kaeta_sandbox/docs/sql/notification_delivery_logs_setup.sql)

## Notes

- 2026-03-15 時点の Supabase CLI `v2.75.0` では `supabase functions invoke ... --body` が使えなかったため、検証は `curl` ベースで統一した
