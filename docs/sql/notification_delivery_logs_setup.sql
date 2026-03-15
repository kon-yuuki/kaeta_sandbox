-- notification_jobs delivery summary + delivery logs
alter table public.notification_jobs
  add column if not exists delivery_summary jsonb;

create table if not exists public.notification_job_delivery_logs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.notification_jobs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  attempt integer not null,
  outcome text not null,
  total_tokens integer not null default 0,
  sent_count integer not null default 0,
  failed_count integer not null default 0,
  deleted_count integer not null default 0,
  detail jsonb not null default '{}'::jsonb,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists notification_job_delivery_logs_job_id_created_at_idx
  on public.notification_job_delivery_logs(job_id, created_at desc);

create index if not exists notification_job_delivery_logs_outcome_created_at_idx
  on public.notification_job_delivery_logs(outcome, created_at desc);

alter table public.notification_job_delivery_logs
  drop constraint if exists notification_job_delivery_logs_outcome_check;

alter table public.notification_job_delivery_logs
  add constraint notification_job_delivery_logs_outcome_check
  check (outcome in ('sent', 'partial_failure', 'failed'));
