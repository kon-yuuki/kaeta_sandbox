create or replace function public.set_notification_reaction(
  p_notification_id text,
  p_emoji text
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
  v_event_id uuid;
  v_family_id uuid;
  v_target_actor_user_id uuid;
  v_previous_emoji text;
  v_already_notified boolean := false;
  v_reaction_event_id uuid := gen_random_uuid();
  v_reactor_name text;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  select n.event_id, n.family_id, n.actor_user_id
    into v_event_id, v_family_id, v_target_actor_user_id
  from public.app_notifications n
  where n.id = p_notification_id
    and n.user_id = v_user;

  if v_event_id is null then
    raise exception 'notification not found';
  end if;

  select r.emoji
    into v_previous_emoji
  from public.app_notification_reactions r
  where r.event_id = v_event_id
    and r.user_id = v_user;

  if p_emoji is null or btrim(p_emoji) = '' then
    delete from public.app_notification_reactions r
    where r.event_id = v_event_id
      and r.user_id = v_user;
    return;
  end if;

  insert into public.app_notification_reactions (event_id, family_id, user_id, emoji)
  values (v_event_id, v_family_id, v_user, p_emoji)
  on conflict (event_id, user_id)
  do update set emoji = excluded.emoji, updated_at = now();

  if v_target_actor_user_id is null or v_target_actor_user_id = v_user then
    return;
  end if;

  if v_previous_emoji is not distinct from p_emoji then
    return;
  end if;

  select coalesce(nullif(trim(p.display_name), ''), 'メンバー')
    into v_reactor_name
  from public.profiles p
  where p.id = v_user;

  if v_reactor_name is null then
    v_reactor_name := 'メンバー';
  end if;

  select exists (
    select 1
    from public.notification_jobs j
    where j.user_id = v_target_actor_user_id
      and coalesce(j.data->>'event_kind', '') = 'reaction_sent'
      and coalesce(j.data->>'source_event_id', '') = v_event_id::text
      and coalesce(j.data->>'actor_user_id', '') = v_user::text
      and coalesce(j.data->>'reaction_emoji', '') = p_emoji
      and j.created_at >= now() - interval '5 minutes'
  )
    into v_already_notified;

  if v_already_notified then
    return;
  end if;

  insert into public.app_notifications (
    message, title, body, type, is_read, user_id, actor_user_id, family_id, event_id
  )
  values (
    'あなたに' || p_emoji || 'でリアクション',
    v_reactor_name,
    'あなたに' || p_emoji || 'でリアクション',
    0,
    false,
    v_target_actor_user_id,
    v_user,
    v_family_id,
    v_reaction_event_id
  );

  insert into public.notification_jobs (
    user_id,
    title,
    body,
    data
  )
  values (
    v_target_actor_user_id,
    v_reactor_name,
    'あなたに' || p_emoji || 'でリアクション',
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', coalesce(v_family_id::text, ''),
      'event_id', v_reaction_event_id::text,
      'type', '0',
      'event_kind', 'reaction_sent',
      'source_event_id', v_event_id::text,
      'reaction_emoji', p_emoji,
      'actor_name', v_reactor_name,
      'actor_user_id', v_user::text
    )
  );
end;
$function$;
