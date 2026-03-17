-- アイテム追加通知を既存 notify_family_members から切り離すための専用RPC
-- Step 4:
-- - app_notifications は従来どおり item 名つきメッセージを 1 件ずつ作成
-- - push 用 notification_jobs は、同じ actor/family の pending job が残っていれば件数を加算
-- - 次段階の worker 対応に向けて aggregate_until を data に持たせる
-- - まだ worker は aggregate_until を見ないので、送信タイミングは従来どおり

create or replace function public.notify_family_members_item_added_batched(
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
  v_actor_name text;
  v_push_title text := 'リストにアイテムが追加されました';
  v_push_body text;
  v_is_item_added boolean := p_type = 0 and p_message like '「%」をリストに追加しました！';
  v_updated_count integer := 0;
  v_aggregate_until timestamptz := now() + interval '2 minutes';
begin
  if not v_is_item_added then
    perform public.notify_family_members(
      p_family_id := p_family_id,
      p_message := p_message,
      p_type := p_type
    );
    return;
  end if;

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

  v_push_body := v_actor_name || 'さんが1個のアイテムを追加しました';

  insert into public.app_notifications (
    message, type, is_read, user_id, actor_user_id, family_id, event_id
  )
  select
    p_message,
    p_type,
    false,
    fm.user_id,
    v_actor,
    fm.family_id,
    v_event_id
  from public.family_members fm
  where fm.family_id = p_family_id;

  update public.notification_jobs j
  set
    title = v_push_title,
    body = v_actor_name || 'さんが'
      || ((coalesce(j.data->>'aggregate_count', '0'))::int + 1)::text
      || '個のアイテムを追加しました',
    data = coalesce(j.data, '{}'::jsonb)
      || jsonb_build_object(
        'screen', 'notifications',
        'family_id', p_family_id::text,
        'event_id', v_event_id::text,
        'type', p_type::text,
        'source_message', p_message,
        'aggregate_kind', 'shopping_added',
        'aggregate_actor_user_id', v_actor::text,
        'aggregate_actor_name', v_actor_name,
        'aggregate_count', ((coalesce(j.data->>'aggregate_count', '0'))::int + 1)::text,
        'aggregate_until', to_char(v_aggregate_until at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )
  where j.id in (
    select j2.id
    from public.notification_jobs j2
    where j2.user_id in (
        select fm.user_id
        from public.family_members fm
        where fm.family_id = p_family_id
          and fm.user_id <> v_actor
      )
      and j2.status = 'pending'
      and coalesce(j2.data->>'aggregate_kind', '') = 'shopping_added'
      and coalesce(j2.data->>'aggregate_actor_user_id', '') = v_actor::text
      and coalesce(j2.data->>'family_id', '') = p_family_id::text
      and coalesce(j2.data->>'type', '') = p_type::text
  );

  get diagnostics v_updated_count = row_count;

  if v_updated_count = 0 then
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
        'source_message', p_message,
        'aggregate_kind', 'shopping_added',
        'aggregate_actor_user_id', v_actor::text,
        'aggregate_actor_name', v_actor_name,
        'aggregate_count', '1',
        'aggregate_until', to_char(v_aggregate_until at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
      )
    from public.family_members fm
    where fm.family_id = p_family_id
      and fm.user_id <> v_actor;
  end if;
end;
$function$;
