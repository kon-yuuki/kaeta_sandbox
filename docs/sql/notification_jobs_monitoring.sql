-- notification_jobs monitoring queries

-- 直近の配送結果
select id, user_id, status, attempts, last_error, delivery_summary, created_at, processed_at
from public.notification_jobs
order by created_at desc
limit 50;

-- failed jobs（再送上限未満）
select id, user_id, attempts, last_error, created_at, processed_at
from public.notification_jobs
where status = 'failed'
  and attempts < 3
order by processed_at desc nulls last
limit 50;

-- 再送上限に達した failed jobs
select id, user_id, attempts, last_error, created_at, processed_at
from public.notification_jobs
where status = 'failed'
  and attempts >= 3
order by processed_at desc nulls last
limit 50;

-- processing のまま停滞している jobs
select id, user_id, attempts, created_at, processed_at
from public.notification_jobs
where status = 'processing'
  and created_at < now() - interval '30 minutes'
order by created_at asc;

-- 日次集計
select
  date_trunc('day', created_at) as day,
  status,
  count(*) as jobs
from public.notification_jobs
group by 1, 2
order by 1 desc, 2 asc;

-- 一部成功 / 全失敗を含む配送ログ
select
  job_id,
  user_id,
  attempt,
  outcome,
  total_tokens,
  sent_count,
  failed_count,
  deleted_count,
  last_error,
  created_at
from public.notification_job_delivery_logs
order by created_at desc
limit 100;
