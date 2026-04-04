create or replace function public.notify_family_members_board_updated(
  p_family_id uuid,
  p_message text,
  p_type integer default 0,
  p_board_message text default null
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
  v_trimmed_board_message text := coalesce(nullif(trim(p_board_message), ''), '');
  v_preview text;
  v_suffix text := '';
  v_push_title text := 'ひとこと掲示板が更新されました';
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

  if char_length(v_trimmed_board_message) > 20 then
    v_preview := left(v_trimmed_board_message, 20);
    v_suffix := '…';
  else
    v_preview := v_trimmed_board_message;
  end if;

  if v_preview is null or v_preview = '' then
    v_push_body := v_actor_name || 'さんがひとことを更新しました';
  else
    v_push_body := v_actor_name || 'さんがひとことを更新: ' || v_preview || v_suffix;
  end if;

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
      'event_kind', 'board_updated',
      'board_message', v_trimmed_board_message,
      'actor_name', v_actor_name,
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;
