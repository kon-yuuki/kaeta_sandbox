-- push_debug_logs: TestFlight実機のPushトークン同期切り分け用（一時導入）
create table if not exists public.push_debug_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  step text not null,
  status text,
  error text,
  token_prefix text,
  source text,
  created_at timestamptz not null default now()
);

create index if not exists push_debug_logs_user_id_created_at_idx
  on public.push_debug_logs(user_id, created_at desc);

alter table public.push_debug_logs enable row level security;

drop policy if exists "push_debug_logs_select_own" on public.push_debug_logs;
create policy "push_debug_logs_select_own"
on public.push_debug_logs
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "push_debug_logs_insert_own" on public.push_debug_logs;
create policy "push_debug_logs_insert_own"
on public.push_debug_logs
for insert
to authenticated
with check (auth.uid() = user_id);
