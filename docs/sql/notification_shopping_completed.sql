create or replace function public.notify_family_members_shopping_completed_batched(
  p_family_id uuid,
  p_message text,
  p_type integer default 1,
  p_completed_count integer default 1
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
  v_increment integer := greatest(coalesce(p_completed_count, 1), 1);
  v_pending_count integer := 0;
  v_aggregate_until timestamptz := now() + interval '2 minutes';
  v_updated_count integer := 0;
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
    v_increment,
    now(),
    now(),
    nullif(trim(p_message), ''),
    null
  )
  on conflict (family_id, actor_user_id)
  do update
    set pending_count = public.shopping_completion_aggregation_state.pending_count + v_increment,
        first_pending_completed_at = coalesce(
          public.shopping_completion_aggregation_state.first_pending_completed_at,
          now()
        ),
        last_pending_completed_at = now(),
        last_pending_item_name = nullif(trim(p_message), '');

  select s.pending_count
    into v_pending_count
  from public.shopping_completion_aggregation_state s
  where s.family_id = p_family_id
    and s.actor_user_id = v_actor;

  update public.notification_jobs j
  set
    title = v_actor_name || 'さんが' || v_pending_count::text || '件の買い物を完了しました',
    body = '',
    data = coalesce(j.data, '{}'::jsonb)
      || jsonb_build_object(
        'screen', 'notifications',
        'family_id', p_family_id::text,
        'event_id', v_event_id::text,
        'type', p_type::text,
        'event_kind', 'shopping_completed',
        'aggregate_kind', 'shopping_completed',
        'aggregate_actor_user_id', v_actor::text,
        'aggregate_actor_name', v_actor_name,
        'aggregate_count', v_pending_count::text,
        'aggregate_until', to_char(v_aggregate_until at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'pending_count', v_pending_count::text,
        'actor_name', v_actor_name,
        'actor_user_id', v_actor::text
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
      and coalesce(j2.data->>'aggregate_kind', '') = 'shopping_completed'
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
      v_actor_name || 'さんが' || v_pending_count::text || '件の買い物を完了しました',
      '',
      jsonb_build_object(
        'screen', 'notifications',
        'family_id', p_family_id::text,
        'event_id', v_event_id::text,
        'type', p_type::text,
        'event_kind', 'shopping_completed',
        'aggregate_kind', 'shopping_completed',
        'aggregate_actor_user_id', v_actor::text,
        'aggregate_actor_name', v_actor_name,
        'aggregate_count', v_pending_count::text,
        'aggregate_until', to_char(v_aggregate_until at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'pending_count', v_pending_count::text,
        'actor_name', v_actor_name,
        'actor_user_id', v_actor::text
      )
    from public.family_members fm
    where fm.family_id = p_family_id
      and fm.user_id <> v_actor;
  end if;
end;
$function$;
