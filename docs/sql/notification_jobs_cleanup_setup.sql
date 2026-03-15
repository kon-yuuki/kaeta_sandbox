-- notification_jobs cleanup
-- 方針:
--   - sent: 7日保持
--   - failed: 30日保持
--   - processing: 30分以上停滞していたら failed に戻す
--   - failed は worker が attempts < 3 の間、自動再送対象

create extension if not exists pg_cron;

create or replace function public.cleanup_notification_jobs()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update public.notification_jobs
  set
    status = 'failed',
    last_error = coalesce(last_error, 'processing_timeout'),
    processed_at = now()
  where status = 'processing'
    and created_at < now() - interval '30 minutes';

  delete from public.notification_jobs
  where status = 'sent'
    and processed_at < now() - interval '7 days';

  delete from public.notification_jobs
  where status = 'failed'
    and processed_at < now() - interval '30 days';
end;
$function$;

select cron.unschedule('cleanup-notification-jobs')
where exists (
  select 1
  from cron.job
  where jobname = 'cleanup-notification-jobs'
);

select cron.schedule(
  'cleanup-notification-jobs',
  '15 3 * * *',
  $$select public.cleanup_notification_jobs();$$
);
