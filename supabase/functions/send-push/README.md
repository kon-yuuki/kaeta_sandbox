# send-push (Supabase Edge Function)

`device_tokens` に保存されたFCMトークンへ通知送信する関数です。

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

## Invoke (example)

```bash
supabase functions invoke send-push --body '{
  "user_id":"<target-user-uuid>",
  "title":"テスト通知",
  "body":"FCMテストです",
  "data":{"screen":"notifications"}
}'
```

## Response

- `sent`: 送信成功件数
- `failed`: 送信失敗件数
- `deleted`: 失効トークン削除件数
