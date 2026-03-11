-- family_members.created_at を追加（未存在時）
alter table public.family_members
  add column if not exists created_at timestamptz not null default now();

-- 既存行のNULLを埋める（念のため）
update public.family_members
set created_at = now()
where created_at is null;

-- オーナー移譲など「古い順」参照向けのインデックス
create index if not exists family_members_family_created_at_idx
  on public.family_members(family_id, created_at, user_id);
