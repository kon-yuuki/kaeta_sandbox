create or replace function public.notify_family_members_team_joined(
  p_family_id uuid,
  p_message text,
  p_type integer default 0
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
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;

  -- 参加通知では actor の family_members チェックを省略。
  -- joinFamily() がローカル PowerSync DB に書き込むため、
  -- Supabase 同期前にこの RPC が呼ばれると actor がまだ
  -- サーバー側 family_members に存在しない場合がある。

  select coalesce(nullif(trim(p.display_name), ''), 'メンバー')
    into v_actor_name
  from public.profiles p
  where p.id = v_actor;

  v_push_title := v_actor_name || 'さんがチームに参加しました';
  v_push_body := 'お買い物完了時にはリアクションができます';

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

  insert into public.notification_jobs (user_id, title, body, data)
  select
    fm.user_id,
    v_push_title,
    v_push_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', p_family_id::text,
      'event_id', v_event_id::text,
      'type', p_type::text,
      'event_kind', 'team_joined',
      'actor_name', v_actor_name,
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;

create or replace function public.notify_family_members_team_left(
  p_family_id uuid,
  p_message text,
  p_type integer default 0
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
  v_push_body text := '';
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

  v_push_title := v_actor_name || 'さんがチームを退出しました';

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

  insert into public.notification_jobs (user_id, title, body, data)
  select
    fm.user_id,
    v_push_title,
    v_push_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', p_family_id::text,
      'event_id', v_event_id::text,
      'type', p_type::text,
      'event_kind', 'team_left',
      'actor_name', v_actor_name,
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;

create or replace function public.notify_family_members_team_deleted(
  p_family_id uuid,
  p_message text,
  p_type integer default 0
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_event_id uuid := gen_random_uuid();
  v_push_title text := 'オーナーがチームを削除しました';
  v_push_body text := '';
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

  -- チーム削除後はチームにアクセスできなくなるため、
  -- family_id を NULL にして個人モードの通知一覧に表示する。
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
    null,
    v_event_id
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;

  insert into public.notification_jobs (user_id, title, body, data)
  select
    fm.user_id,
    v_push_title,
    v_push_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', p_family_id::text,
      'event_id', v_event_id::text,
      'type', p_type::text,
      'event_kind', 'team_deleted',
      'actor_user_id', v_actor::text
    )
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_actor;
end;
$function$;

create or replace function public.notify_user_removed_from_team(
  p_family_id uuid,
  p_removed_user_id uuid,
  p_team_name text,
  p_type integer default 0
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_event_id uuid := gen_random_uuid();
  v_push_title text := 'チームから退出されました';
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

  v_push_body := p_team_name || ' のオーナーがあなたを退出させました';

  -- 強制退出された人はチームにアクセスできなくなるため、
  -- family_id を NULL にして個人モードの通知一覧に表示する。
  insert into public.app_notifications (
    message, title, body, type, is_read, user_id, actor_user_id, family_id, event_id
  )
  values (
    v_push_body,
    v_push_title,
    v_push_body,
    p_type,
    false,
    p_removed_user_id,
    v_actor,
    null,
    v_event_id
  );

  insert into public.notification_jobs (user_id, title, body, data)
  values (
    p_removed_user_id,
    v_push_title,
    v_push_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', p_family_id::text,
      'event_id', v_event_id::text,
      'type', p_type::text,
      'event_kind', 'removed_from_team',
      'team_name', p_team_name,
      'actor_user_id', v_actor::text
    )
  );
end;
$function$;
