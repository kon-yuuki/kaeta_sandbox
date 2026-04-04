alter table public.app_notifications
  add column if not exists title text;

alter table public.app_notifications
  add column if not exists body text;

create or replace function public.notify_family_members(
  p_family_id uuid,
  p_message text,
  p_type integer default 1
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_event_id uuid := gen_random_uuid();
  v_title text := 'Kaeta';
  v_body text := p_message;
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.family_members fm
    where fm.family_id = p_family_id
      and fm.user_id = v_actor
  ) then
    raise exception 'not a family member';
  end if;

  insert into public.app_notifications (
    message,
    title,
    body,
    type,
    is_read,
    user_id,
    actor_user_id,
    family_id,
    event_id
  )
  select
    p_message,
    v_title,
    v_body,
    p_type,
    false,
    fm.user_id,
    v_actor,
    fm.family_id,
    v_event_id
  from public.family_members fm
  where fm.family_id = p_family_id;

  insert into public.notification_jobs (
    user_id,
    title,
    body,
    data
  )
  select
    fm.user_id,
    v_title,
    v_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', p_family_id::text,
      'event_id', v_event_id::text,
      'type', p_type::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;

-- NOTE:
-- 既存の専用通知 SQL も app_notifications.title/body を同じ文言で保存する形へ
-- そろえる必要がある。現時点では、以下のファイル群の最新版を順に適用する想定。
-- - docs/sql/item_add_push_batching.sql
-- - docs/sql/notification_shopping_completed.sql
-- - docs/sql/notification_shopping_all_completed.sql
-- - docs/sql/notification_item_edited_deleted.sql
-- - docs/sql/notification_reaction.sql
-- - docs/sql/notification_team_events.sql
