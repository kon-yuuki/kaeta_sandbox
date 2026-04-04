create or replace function public.notify_family_members_item_edited(
  p_family_id uuid,
  p_message text,
  p_type integer default 0,
  p_item_name text default null
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
  v_item_name text := coalesce(nullif(trim(p_item_name), ''), 'アイテム');
  v_push_title text;
  v_push_body text;
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

  v_push_title := '編集されたアイテムがあります';
  v_push_body := v_actor_name || 'さんが' || v_item_name || 'を編集しました';

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
  where fm.family_id = p_family_id;

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
      'event_kind', 'item_edited',
      'item_name', v_item_name,
      'actor_name', v_actor_name,
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;

create or replace function public.notify_family_members_item_deleted(
  p_family_id uuid,
  p_message text,
  p_type integer default 0,
  p_item_name text default null
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
  v_item_name text := coalesce(nullif(trim(p_item_name), ''), 'アイテム');
  v_push_title text;
  v_push_body text;
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

  v_push_title := '削除されたアイテムがあります';
  v_push_body := v_actor_name || 'さんが' || v_item_name || 'を削除しました';

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
  where fm.family_id = p_family_id;

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
      'event_kind', 'item_deleted',
      'item_name', v_item_name,
      'actor_name', v_actor_name,
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;
