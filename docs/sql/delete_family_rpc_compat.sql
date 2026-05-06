-- delete_family の互換修正
-- 背景:
-- - 一部環境では family_id 列がまだ text のまま
-- - 既存の delete_family(p_family_id uuid) 内で
--   `where family_id = p_family_id` を行うと text = uuid で 42883 になる
--
-- この版は比較時に p_family_id::text を使い、
-- family_id が text の環境でも uuid の環境でも動くようにする。

create or replace function public.delete_family(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  v_uid uuid := auth.uid();
  v_family_id_text text := p_family_id::text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_family_id is null then
    raise exception 'family_id is required';
  end if;

  if not exists (
    select 1
    from public.families f
    where f.id = p_family_id
      and f.owner_id = v_uid
  ) then
    raise exception 'forbidden: only owner can delete family';
  end if;

  update public.profiles p
  set current_family_id = null
  where p.id::text in (
    select fm.user_id::text
    from public.family_members fm
    where fm.family_id::text = v_family_id_text
  )
    and p.current_family_id::text = v_family_id_text;

  delete from public.app_notification_reactions
  where family_id::text = v_family_id_text;

  delete from public.app_notifications
  where family_id::text = v_family_id_text;

  delete from public.todo_items
  where family_id::text = v_family_id_text;

  delete from public.purchase_history
  where family_id::text = v_family_id_text;

  delete from public.family_boards
  where family_id::text = v_family_id_text;

  delete from public.invitations
  where family_id::text = v_family_id_text;

  delete from public.items
  where family_id::text = v_family_id_text;

  delete from public.categories
  where family_id::text = v_family_id_text;

  delete from public.family_members
  where family_id::text = v_family_id_text;

  delete from public.families
  where id = p_family_id;
end;
$function$;

grant execute on function public.delete_family(uuid) to authenticated;
