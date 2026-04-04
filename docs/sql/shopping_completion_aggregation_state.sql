-- shopping completion aggregation state
-- 目的:
-- - 一部購入完了通知 / 全件購入完了通知で「未通知分のみ」を数えるための状態を保持する
-- - notification_jobs は outbox に専念させ、集約の真実は専用テーブルで持つ

create table if not exists public.shopping_completion_aggregation_state (
  family_id uuid not null references public.families(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  pending_count integer not null default 0,
  first_pending_completed_at timestamptz,
  last_pending_completed_at timestamptz,
  last_pending_item_name text,
  last_notified_completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (family_id, actor_user_id)
);

create index if not exists shopping_completion_aggregation_state_updated_at_idx
  on public.shopping_completion_aggregation_state(updated_at desc);

create or replace function public.set_shopping_completion_aggregation_state_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

drop trigger if exists trg_shopping_completion_aggregation_state_updated_at
  on public.shopping_completion_aggregation_state;

create trigger trg_shopping_completion_aggregation_state_updated_at
before update on public.shopping_completion_aggregation_state
for each row execute function public.set_shopping_completion_aggregation_state_updated_at();
