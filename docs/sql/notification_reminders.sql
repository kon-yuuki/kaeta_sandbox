-- Reminder notifications
-- 目的:
-- - リマインド通知を app_notifications / notification_jobs に直接積む
-- - Flutter 常駐ではなく、Supabase 側の定期実行で配信する
--
-- 前提:
-- - public.app_notifications.title/body が存在する
-- - public.notification_jobs が存在する
-- - public.family_members.created_at が存在する
--
-- 補足:
-- - 招待リマインドの「family 作成から24時間」は families.created_at がないため、
--   owner の family_members.created_at を家族作成時刻相当として扱う
-- - 未完了 24h / 48h の「最終更新」は、todo_items の created_at / completed_at の最新時刻で判定する
--   未完了アイテム名の更新は別途 updated_at がないため、この定義で近似する

create or replace function public.enqueue_invite_reminder_24h()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_now timestamptz := now();
  v_today_jst date := (timezone('Asia/Tokyo', v_now))::date;
  v_inserted_count integer := 0;
begin
  with candidate_families as (
    select
      f.id as family_id,
      f.owner_id,
      fm_owner.created_at as family_started_at
    from public.families f
    join public.family_members fm_owner
      on fm_owner.family_id = f.id
     and fm_owner.user_id = f.owner_id
    where fm_owner.created_at <= v_now - interval '24 hours'
      and (
        select count(*)
        from public.family_members fm
        where fm.family_id = f.id
      ) = 1
  ),
  deduped as (
    select c.*
    from candidate_families c
    where not exists (
      select 1
      from public.notification_jobs j
      where coalesce(j.data->>'event_kind', '') = 'invite_reminder_24h'
        and coalesce(j.data->>'family_id', '') = c.family_id::text
        and coalesce(j.data->>'reminder_date', '') = v_today_jst::text
    )
  ),
  created_notifications as (
    insert into public.app_notifications (
      message, title, body, type, is_read, user_id, actor_user_id, family_id, event_id
    )
    select
      'チームに家族を招待しましょう',
      'チームに家族を招待しましょう',
      'リンクを受け取った家族は、すぐに始められます',
      0,
      false,
      d.owner_id,
      d.owner_id,
      d.family_id,
      gen_random_uuid()
    from deduped d
    returning user_id, family_id, event_id
  )
  insert into public.notification_jobs (user_id, title, body, data)
  select
    n.user_id,
    'チームに家族を招待しましょう',
    'リンクを受け取った家族は、すぐに始められます',
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', n.family_id::text,
      'event_id', n.event_id::text,
      'type', '0',
      'event_kind', 'invite_reminder_24h',
      'reminder_date', v_today_jst::text,
      'reminder_stage', '24h'
    )
  from created_notifications n;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$function$;

create or replace function public.enqueue_shopping_remaining_reminders()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_now timestamptz := now();
  v_today_jst date := (timezone('Asia/Tokyo', v_now))::date;
  v_inserted_count integer := 0;
begin
  with family_stats as (
    select
      t.family_id,
      count(*) filter (where t.is_completed = false) as remaining_count,
      max(coalesce(t.completed_at, t.created_at)) as last_activity_at
    from public.todo_items t
    where t.family_id is not null
    group by t.family_id
  ),
  reminder_targets as (
    select
      fs.family_id,
      fs.remaining_count,
      case
        when fs.last_activity_at <= v_now - interval '48 hours' then '48h'
        when fs.last_activity_at <= v_now - interval '24 hours' then '24h'
        else null
      end as reminder_stage
    from family_stats fs
    where fs.remaining_count > 0
  ),
  filtered_targets as (
    select
      rt.family_id,
      rt.remaining_count,
      rt.reminder_stage,
      case
        when rt.reminder_stage = '24h' then 'shopping_remaining_24h'
        when rt.reminder_stage = '48h' then 'shopping_remaining_48h'
        else null
      end as event_kind,
      case
        when rt.reminder_stage = '24h'
          then 'リストに' || rt.remaining_count::text || '点のアイテムがあります'
        when rt.reminder_stage = '48h'
          then 'リストに' || rt.remaining_count::text || '点のアイテムが残っています'
        else null
      end as push_title,
      case
        when rt.reminder_stage = '24h' then '確認してみませんか？'
        when rt.reminder_stage = '48h' then '購入は完了していますか？'
        else null
      end as push_body
    from reminder_targets rt
    where rt.reminder_stage is not null
  ),
  deduped as (
    select ft.*
    from filtered_targets ft
    where not exists (
      select 1
      from public.notification_jobs j
      where coalesce(j.data->>'event_kind', '') = ft.event_kind
        and coalesce(j.data->>'family_id', '') = ft.family_id::text
        and coalesce(j.data->>'reminder_date', '') = v_today_jst::text
        and coalesce(j.data->>'reminder_stage', '') = ft.reminder_stage
    )
  ),
  generated_notifications as (
    select
      fm.user_id,
      d.family_id,
      d.event_kind,
      d.reminder_stage,
      d.push_title,
      d.push_body,
      gen_random_uuid() as event_id
    from deduped d
    join public.family_members fm
      on fm.family_id = d.family_id
  ),
  created_notifications as (
    insert into public.app_notifications (
      message, title, body, type, is_read, user_id, actor_user_id, family_id, event_id
    )
    select
      g.push_title,
      g.push_title,
      g.push_body,
      0,
      false,
      g.user_id,
      g.user_id,
      g.family_id,
      g.event_id
    from generated_notifications g
    returning user_id, family_id, title, body, event_id
  )
  insert into public.notification_jobs (user_id, title, body, data)
  select
    g.user_id,
    g.push_title,
    g.push_body,
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', g.family_id::text,
      'event_id', g.event_id::text,
      'type', '0',
      'event_kind', g.event_kind,
      'reminder_date', v_today_jst::text,
      'reminder_stage', g.reminder_stage
    )
  from generated_notifications g;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$function$;

create or replace function public.enqueue_weekend_reminders()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_now timestamptz := now();
  v_now_jst timestamptz := timezone('Asia/Tokyo', v_now);
  v_today_jst date := v_now_jst::date;
  v_inserted_count integer := 0;
begin
  if extract(isodow from v_now_jst) <> 5 then
    return 0;
  end if;

  with candidate_families as (
    select distinct family_id
    from (
      select t.family_id
      from public.todo_items t
      where t.family_id is not null
      union
      select ph.family_id
      from public.purchase_history ph
      where ph.family_id is not null
    ) x
  ),
  deduped as (
    select c.family_id
    from candidate_families c
    where not exists (
      select 1
      from public.notification_jobs j
      where coalesce(j.data->>'event_kind', '') = 'weekend_reminder'
        and coalesce(j.data->>'family_id', '') = c.family_id::text
        and coalesce(j.data->>'reminder_date', '') = v_today_jst::text
    )
  ),
  created_notifications as (
    insert into public.app_notifications (
      message, title, body, type, is_read, user_id, actor_user_id, family_id, event_id
    )
    select
      'お疲れさまです。週末の買い物リストを確認しませんか？',
      'お疲れさまです。週末の買い物リストを確認しませんか？',
      '履歴からワンタップで追加ができます',
      0,
      false,
      fm.user_id,
      fm.user_id,
      d.family_id,
      gen_random_uuid()
    from deduped d
    join public.family_members fm
      on fm.family_id = d.family_id
    returning user_id, family_id, event_id
  )
  insert into public.notification_jobs (user_id, title, body, data)
  select
    n.user_id,
    'お疲れさまです。週末の買い物リストを確認しませんか？',
    '履歴からワンタップで追加ができます',
    jsonb_build_object(
      'screen', 'notifications',
      'family_id', n.family_id::text,
      'event_id', n.event_id::text,
      'type', '0',
      'event_kind', 'weekend_reminder',
      'reminder_date', v_today_jst::text
    )
  from created_notifications n;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$function$;
