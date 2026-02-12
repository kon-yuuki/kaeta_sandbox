# Full Environment Clone Runbook (Supabase + PowerSync)

この手順書は、Kaeta のバックエンド環境を「別 Supabase / 別 PowerSync」に再構築するための実運用向けランブックです。  
前提は「設定をコード化して再適用する」方式です。`pg_dump` の丸コピーは使いません。

---

## 0. 方針（先に結論）

新環境へ切り替えるときは、次の順で実施します。

1. Supabase 側の SQL（テーブル/関数/RLS/publication）を適用
2. PowerSync の `sync_rules.yaml` を適用
3. Flutter の接続先（URL / keys）を新環境へ切替
4. アプリ再起動・再インストールで動作確認

この流れにすると、将来また別アカウントへ移すときも同じ手順で再現できます。

---

## 1. 事前準備

必要情報:

1. 新 Supabase `Project URL`
2. 新 Supabase `anon key`
3. 新 PowerSync エンドポイント
4. 新 PowerSync API key（使っている場合）

---

## 2. Supabase: SQL 適用

SQL Editor で、最低限以下を適用します。

### 2-1. 通知テーブル（`app_notifications`）

```sql
create extension if not exists pgcrypto;

create table if not exists public.app_notifications (
  id text primary key default gen_random_uuid()::text,
  message text not null,
  type integer not null default 0,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  user_id uuid not null,
  actor_user_id uuid,
  family_id text
);

alter table public.app_notifications
  add column if not exists actor_user_id uuid;

alter table public.app_notifications
  add column if not exists family_id text;
```

### 2-2. 通知配信RPC（家族全員向け）

```sql
create or replace function public.notify_family_members(
  p_family_id text,
  p_message text,
  p_type integer default 1
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.family_members fm
    where fm.family_id = p_family_id
      and fm.user_id::text = v_actor::text
  ) then
    raise exception 'not a family member';
  end if;

  insert into public.app_notifications (
    message, type, is_read, user_id, actor_user_id, family_id
  )
  select
    p_message, p_type, false, fm.user_id::uuid, v_actor, p_family_id
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id::text <> v_actor::text;
end;
$$;

grant execute on function public.notify_family_members(text, text, integer) to authenticated;
```

### 2-3. RLS（通知は受信者のみ参照）

```sql
alter table public.app_notifications enable row level security;

drop policy if exists "notif_select_own" on public.app_notifications;
create policy "notif_select_own"
  on public.app_notifications
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "notif_update_own" on public.app_notifications;
create policy "notif_update_own"
  on public.app_notifications
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "notif_delete_own" on public.app_notifications;
create policy "notif_delete_own"
  on public.app_notifications
  for delete
  to authenticated
  using (user_id = auth.uid());
```

### 2-4. PowerSync publication へ追加

```sql
alter publication powersync add table public.app_notifications;
```

必要なら確認:

```sql
select schemaname, tablename
from pg_publication_tables
where pubname = 'powersync'
order by schemaname, tablename;
```

---

## 3. PowerSync: Sync Rules 適用

`sync_rules.yaml` は次の形をベースにします（JOIN/subquery を使わない）。

```yaml
bucket_definitions:
  family_shared_data:
    parameters: >
      SELECT family_id FROM family_members WHERE user_id = request.user_id()
    data:
      - select * from families where id = bucket.family_id
      - select * from family_members where family_id = bucket.family_id
      - select * from profiles where current_family_id = bucket.family_id
      - select * from todo_items where family_id = bucket.family_id
      - select * from items where family_id = bucket.family_id
      - select * from categories where family_id = bucket.family_id
      - select * from purchase_history where family_id = bucket.family_id
      - select * from invitations where family_id = bucket.family_id
      - select * from family_boards where family_id = bucket.family_id

  personal_data:
    parameters: >
      SELECT id as user_id FROM profiles WHERE id = request.user_id()
    data:
      - select * from profiles where id = bucket.user_id
      - select * from app_notifications where user_id = bucket.user_id
      - select * from purchase_history where user_id = bucket.user_id
      - select * from items where user_id = bucket.user_id AND family_id IS NULL
      - select * from categories where user_id = bucket.user_id AND family_id IS NULL
      - select * from todo_items where user_id = bucket.user_id AND family_id IS NULL
      - select * from family_boards where user_id = bucket.user_id AND family_id IS NULL

  global_master:
    data:
      - select * from master_items
```

注意:

1. `data:` 内で `JOIN` や `IN (select ...)` を使うとエラーになります。
2. `profiles where current_family_id = ...` は「1ユーザー1家族運用」を前提にした実装です。

---

## 4. Flutter / Drift 側の整合性

このリポジトリ側では次が揃っていることを確認します。

1. `lib/data/model/schema.dart`
   - `AppNotifications` に `actorUserId`
   - `ps.Schema` に `app_notifications` テーブル定義
2. `lib/data/model/database.dart`
   - `schemaVersion` が最新（現在は `5`）
   - `onUpgrade` に `actor_user_id` 追加処理
3. `lib/data/repositories/notifications_repository.dart`
   - `notifyShoppingCompleted(...)` で `notify_family_members` RPC を呼ぶ
4. `lib/pages/notifications/notifications_screen.dart`
   - 通知の表示アバターは `actorUserId` 優先

生成コード更新:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 5. 接続先切替

次を新環境に差し替えます。

1. Supabase URL
2. Supabase anon key
3. PowerSync endpoint
4. PowerSync key（使っている場合）

CI/CD も同じ値に更新します。

---

## 6. 動作確認（必須）

1. Aユーザーでログイン
2. 家族あり状態でアイテムを完了
3. Bユーザーで通知画面を開く
4. 通知が届くこと
5. 通知アイコンが A（実施者）のプロフィールになっていること

---

## 7. 既知の制約

1. Sync Rules は複雑な SELECT（JOIN / subquery）非対応
2. `profiles.current_family_id` 依存は 1ユーザー1家族前提
3. 将来「家族切替」を厳密対応する場合は、`family_member_profiles` 等の中間テーブル戦略を検討

---

## 8. トラブルシュート

1. `Table ... is not part of publication 'powersync'`
   - `ALTER PUBLICATION powersync ADD TABLE ...` を実行
2. `select not supported here`（sync rules）
   - JOIN / subquery を使っていないか確認
3. 通知が来ない
   - `notify_family_members` 関数の存在・実行権限
   - RLS policy
   - `app_notifications` が publication / sync rules 両方に入っているか

