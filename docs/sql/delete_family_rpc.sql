-- チーム削除RPC（オーナーのみ実行可）
-- 削除対象:
-- - items
-- - purchase_history
-- - family_boards
-- - categories
-- - family_members
-- - invitations
-- - app_notifications / app_notification_reactions (family_id単位)
-- - families
create or replace function public.delete_family(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_uid uuid := auth.uid();
  v_member_ids uuid[];
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_family_id is null then
    raise exception 'family_id is required';
  end if;

  -- オーナーのみ削除可
  if not exists (
    select 1
    from public.families f
    where f.id = p_family_id
      and f.owner_id = v_uid
  ) then
    raise exception 'forbidden: only owner can delete family';
  end if;

  -- 後続で family_members を削除しても通知先を失わないよう、先に対象メンバーを確保
  select coalesce(array_agg(fm.user_id), '{}'::uuid[])
    into v_member_ids
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id <> v_uid;

  -- 参照整合のため、先に所属メンバーの current_family_id を解除
  update public.profiles p
  set current_family_id = null
  where p.id in (
    select fm.user_id
    from public.family_members fm
    where fm.family_id = p_family_id
  )
    and p.current_family_id = p_family_id;

  -- family配下の通知系
  delete from public.app_notification_reactions
  where family_id = p_family_id;

  delete from public.app_notifications
  where family_id = p_family_id;

  -- family配下の実データ
  delete from public.todo_items
  where family_id = p_family_id;

  delete from public.purchase_history
  where family_id = p_family_id;

  delete from public.family_boards
  where family_id = p_family_id;

  delete from public.invitations
  where family_id = p_family_id;

  delete from public.categories
  where family_id = p_family_id;

  delete from public.items
  where family_id = p_family_id;

  -- 紐付けと本体
  delete from public.family_members
  where family_id = p_family_id;

  delete from public.families
  where id = p_family_id;

  -- チーム削除後も確認できるよう、個人通知として残す
  insert into public.app_notifications (
    message, type, is_read, user_id, actor_user_id, family_id
  )
  select
    'オーナーがチームを削除しました',
    0,
    false,
    member_id,
    v_uid,
    null
  from unnest(v_member_ids) as member_id;
end;
$function$;

grant execute on function public.delete_family(uuid) to authenticated;
