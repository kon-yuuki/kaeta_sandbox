create or replace function public.notify_family_members_shopping_all_completed(
  p_family_id uuid,
  p_message text,
  p_type integer default 2,
  p_first_item_name text default null,
  p_completed_count integer default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_event_id uuid := gen_random_uuid();
  v_actor_name text;
  v_push_title text;
  v_push_body text;
  v_first_item_name text := coalesce(nullif(trim(p_first_item_name), ''), 'アイテム');
  v_existing_pending_count integer := 0;
  v_completed_count integer := 0;
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

  select coalesce(nullif(trim(p.display_name), ''), 'メンバー')
    into v_actor_name
  from public.profiles p
  where p.id = v_actor;

  if v_actor_name is null then
    v_actor_name := 'メンバー';
  end if;

  select coalesce(s.pending_count, 0)
    into v_existing_pending_count
  from public.shopping_completion_aggregation_state s
  where s.family_id = p_family_id
    and s.actor_user_id = v_actor;

  v_completed_count := greatest(v_existing_pending_count + 1, 1);

  insert into public.shopping_completion_aggregation_state (
    family_id,
    actor_user_id,
    pending_count,
    first_pending_completed_at,
    last_pending_completed_at,
    last_pending_item_name,
    last_notified_completed_at
  )
  values (
    p_family_id,
    v_actor,
    0,
    null,
    null,
    null,
    now()
  )
  on conflict (family_id, actor_user_id)
  do update
    set pending_count = 0,
        first_pending_completed_at = null,
        last_pending_completed_at = null,
        last_pending_item_name = null,
        last_notified_completed_at = now();

  delete from public.notification_jobs j
  where j.status = 'pending'
    and coalesce(j.data->>'aggregate_kind', '') = 'shopping_completed'
    and coalesce(j.data->>'aggregate_actor_user_id', '') = v_actor::text
    and coalesce(j.data->>'family_id', '') = p_family_id::text
    and j.user_id in (
      select fm.user_id
      from public.family_members fm
      where fm.family_id = p_family_id
        and fm.user_id <> v_actor
    );

  v_push_title := v_actor_name || 'さんがすべての買い物を完了しました';
  v_push_body := v_first_item_name || 'ほか' || v_completed_count::text || '件を購入。アプリからスタンプを送れます';

  insert into public.app_notifications (
    message, title, body, type, is_read, user_id, actor_user_id, family_id, event_id
  )
  select
    p_message,
    v_push_title,
    v_push_body,
    p_type,
    false,
    fm.user_id,
    v_actor,
    fm.family_id,
    v_event_id
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;

  insert into public.notification_jobs (
    user_id,
    title,
    body,
    data
  )
  select
    fm.user_id,
    v_push_title,
    v_push_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', p_family_id::text,
      'event_id', v_event_id::text,
      'type', p_type::text,
      'event_kind', 'shopping_all_completed',
      'first_item_name', v_first_item_name,
      'completed_count', v_completed_count::text,
      'actor_name', v_actor_name,
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;
