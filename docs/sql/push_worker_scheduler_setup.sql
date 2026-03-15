-- push worker scheduler setup
-- 前提:
--   - pg_cron extension が有効
--   - pg_net extension が有効
--   - vault に project_url と publishable_key が登録済み
--
-- 例:
-- select vault.create_secret('https://fkkvqxbzvysimylzedus.supabase.co', 'project_url');
-- select vault.create_secret('<YOUR_SUPABASE_ANON_KEY>', 'publishable_key');

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 念のため既存ジョブを削除
select cron.unschedule('process-notification-jobs')
where exists (
  select 1
  from cron.job
  where jobname = 'process-notification-jobs'
);

-- 1分ごとに pending jobs を処理
select cron.schedule(
  'process-notification-jobs',
  '* * * * *',
  $$
  select
    net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
        || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (
          select decrypted_secret from vault.decrypted_secrets where name = 'publishable_key'
        ),
        'apikey', (
          select decrypted_secret from vault.decrypted_secrets where name = 'publishable_key'
        )
      ),
      body := jsonb_build_object(
        'mode', 'process_pending',
        'batch_size', 20
      )
    );
  $$
);

-- 確認
-- select jobid, jobname, schedule, command, active
-- from cron.job
-- where jobname = 'process-notification-jobs';

-- 実行履歴確認
-- select jobid, runid, status, return_message, start_time, end_time
-- from cron.job_run_details
-- where jobid = (
--   select jobid from cron.job where jobname = 'process-notification-jobs'
-- )
-- order by start_time desc
-- limit 20;
