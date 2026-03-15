-- notification_jobs: push 配信 worker 用 outbox
create table if not exists public.notification_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists notification_jobs_status_created_at_idx
  on public.notification_jobs(status, created_at);

create index if not exists notification_jobs_user_id_created_at_idx
  on public.notification_jobs(user_id, created_at desc);

alter table public.notification_jobs
  drop constraint if exists notification_jobs_status_check;

alter table public.notification_jobs
  add constraint notification_jobs_status_check
  check (status in ('pending', 'processing', 'sent', 'failed'));
