-- reminder notification scheduler setup
-- 前提:
-- - pg_cron extension が有効
-- - notification_reminders.sql を適用済み
--
-- 方針:
-- - 招待 24h / 未完了 24h / 未完了 48h は毎時実行
-- - 週末リマインドは金曜 17:00 JST に実行

create extension if not exists pg_cron;

select cron.unschedule('enqueue-invite-reminder-24h')
where exists (
  select 1
  from cron.job
  where jobname = 'enqueue-invite-reminder-24h'
);

select cron.unschedule('enqueue-shopping-remaining-reminders')
where exists (
  select 1
  from cron.job
  where jobname = 'enqueue-shopping-remaining-reminders'
);

select cron.unschedule('enqueue-weekend-reminders')
where exists (
  select 1
  from cron.job
  where jobname = 'enqueue-weekend-reminders'
);

-- 毎時 5 分に招待リマインドをチェック
select cron.schedule(
  'enqueue-invite-reminder-24h',
  '5 * * * *',
  $$select public.enqueue_invite_reminder_24h();$$
);

-- 毎時 10 分に未完了リマインドをチェック
select cron.schedule(
  'enqueue-shopping-remaining-reminders',
  '10 * * * *',
  $$select public.enqueue_shopping_remaining_reminders();$$
);

-- JST 金曜 17:00 は UTC 金曜 08:00
select cron.schedule(
  'enqueue-weekend-reminders',
  '0 8 * * 5',
  $$select public.enqueue_weekend_reminders();$$
);

-- 確認
-- select jobid, jobname, schedule, command, active
-- from cron.job
-- where jobname in (
--   'enqueue-invite-reminder-24h',
--   'enqueue-shopping-remaining-reminders',
--   'enqueue-weekend-reminders'
-- );
