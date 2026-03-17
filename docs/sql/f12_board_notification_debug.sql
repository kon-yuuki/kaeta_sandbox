-- F-12 ひとこと掲示板更新通知 調査用SQL
-- 使い方:
-- 1. ひとこと掲示板を更新した直後に上から順に実行
-- 2. app_notifications / notification_jobs / notification_job_delivery_logs に
--    レコードが入るかを見て、producer 側か worker 側かを切り分ける

-- ------------------------------------------------------------
-- 0. RPC定義の実体確認
-- ------------------------------------------------------------
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as args,
  pg_get_functiondef(p.oid) as function_def
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname = 'notify_family_members';

-- ------------------------------------------------------------
-- 1. 最近の掲示板更新っぽい通知レコード
-- ------------------------------------------------------------
select
  id,
  user_id,
  actor_user_id,
  family_id,
  type,
  message,
  event_id,
  is_read,
  created_at
from public.app_notifications
where message like '%さんがひとことを更新:%'
order by created_at desc
limit 30;

-- ------------------------------------------------------------
-- 2. 最近の notification_jobs
-- ------------------------------------------------------------
select
  id,
  user_id,
  status,
  attempts,
  title,
  body,
  data,
  created_at,
  processed_at,
  delivery_summary
from public.notification_jobs
where body like '%さんがひとことを更新:%'
order by created_at desc
limit 30;

-- ------------------------------------------------------------
-- 3. 最近の delivery logs
-- ------------------------------------------------------------
select
  l.id,
  l.job_id,
  l.outcome,
  l.last_error,
  l.created_at
from public.notification_job_delivery_logs l
join public.notification_jobs j on j.id = l.job_id
where j.body like '%さんがひとことを更新:%'
order by l.created_at desc
limit 30;


-- ------------------------------------------------------------
-- 4. 最新1件の通知から producer / worker を縦に追う
-- ------------------------------------------------------------
with latest_board_notification as (
  select *
  from public.app_notifications
  where message like '%さんがひとことを更新:%'
  order by created_at desc
  limit 1
)
select
  n.id as notification_id,
  n.user_id,
  n.actor_user_id,
  n.family_id,
  n.type,
  n.message,
  n.created_at as notification_created_at,
  j.id as job_id,
  j.status as job_status,
  j.attempts,
  j.title,
  j.body,
  j.data,
  j.created_at as job_created_at,
  j.processed_at,
  j.delivery_summary
from latest_board_notification n
left join public.notification_jobs j
  on j.user_id = n.user_id
 and j.body = n.message
 and j.created_at >= n.created_at - interval '10 seconds'
 and j.created_at <= n.created_at + interval '10 seconds'
order by j.created_at desc nulls last;

-- ------------------------------------------------------------
-- 5. 最近5分の件数確認
-- ------------------------------------------------------------
select
  'app_notifications' as source,
  count(*) as count
from public.app_notifications
where created_at >= now() - interval '5 minutes'
  and message like '%さんがひとことを更新:%'
union all
select
  'notification_jobs' as source,
  count(*) as count
from public.notification_jobs
where created_at >= now() - interval '5 minutes'
  and body like '%さんがひとことを更新:%';

-- ------------------------------------------------------------
-- 6. 通知設定の持ち方確認用
--    notify_board_updates がどこに保存されているかを探す時に使う
-- ------------------------------------------------------------
select
  table_schema,
  table_name,
  column_name
from information_schema.columns
where column_name ilike '%notify%'
order by table_schema, table_name, column_name;
