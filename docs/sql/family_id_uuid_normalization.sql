-- family_id 型混在の根本修正
-- 目的:
-- - public.app_notifications.family_id (text) -> uuid
-- - public.app_notification_reactions.family_id (text) -> uuid
-- - public.items.family_id (text) -> uuid
-- - public.categories.family_id (text) -> uuid
-- を uuid に統一し、families.id と同じ型に揃える
--
-- 実行前チェック:
-- 1. 不正な family_id 文字列がないこと
-- 2. 既存の FK/Index 名が違う場合は適宜読み替えること

begin;

-- 事前確認: uuid に変換できない値が残っていないか
do $$
declare
  invalid_count integer;
begin
  select count(*) into invalid_count
  from public.app_notifications
  where family_id is not null
    and family_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  if invalid_count > 0 then
    raise exception 'app_notifications.family_id に uuid 変換不可の値が % 件あります', invalid_count;
  end if;

  select count(*) into invalid_count
  from public.app_notification_reactions
  where family_id is not null
    and family_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  if invalid_count > 0 then
    raise exception 'app_notification_reactions.family_id に uuid 変換不可の値が % 件あります', invalid_count;
  end if;

  select count(*) into invalid_count
  from public.items
  where family_id is not null
    and family_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  if invalid_count > 0 then
    raise exception 'items.family_id に uuid 変換不可の値が % 件あります', invalid_count;
  end if;

  select count(*) into invalid_count
  from public.categories
  where family_id is not null
    and family_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  if invalid_count > 0 then
    raise exception 'categories.family_id に uuid 変換不可の値が % 件あります', invalid_count;
  end if;
end $$;

-- 既存 FK を落とす（存在する場合のみ）
alter table public.app_notification_reactions
  drop constraint if exists app_notification_reactions_family_id_fkey;

alter table public.app_notifications
  drop constraint if exists app_notifications_family_id_fkey;

alter table public.items
  drop constraint if exists items_family_id_fkey;

alter table public.categories
  drop constraint if exists categories_family_id_fkey;

-- 型変換
alter table public.app_notification_reactions
  alter column family_id type uuid using family_id::uuid;

alter table public.app_notifications
  alter column family_id type uuid using family_id::uuid;

alter table public.items
  alter column family_id type uuid using family_id::uuid;

alter table public.categories
  alter column family_id type uuid using family_id::uuid;

-- FK を再付与
alter table public.app_notification_reactions
  add constraint app_notification_reactions_family_id_fkey
  foreign key (family_id) references public.families(id) on delete cascade;

alter table public.app_notifications
  add constraint app_notifications_family_id_fkey
  foreign key (family_id) references public.families(id) on delete cascade;

alter table public.items
  add constraint items_family_id_fkey
  foreign key (family_id) references public.families(id) on delete cascade;

alter table public.categories
  add constraint categories_family_id_fkey
  foreign key (family_id) references public.families(id) on delete cascade;

commit;
