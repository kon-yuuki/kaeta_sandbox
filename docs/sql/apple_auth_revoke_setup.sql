-- Sign in with Apple revoke token storage
-- Edge Function `apple-auth-revoke` uses this table with the service role.
-- Keep RLS enabled and do not expose row access to app clients.

create table if not exists public.apple_auth_revoke_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  updated_at timestamptz not null default now()
);

alter table public.apple_auth_revoke_tokens enable row level security;

revoke all on table public.apple_auth_revoke_tokens from anon;
revoke all on table public.apple_auth_revoke_tokens from authenticated;
grant all on table public.apple_auth_revoke_tokens to service_role;

create or replace function public.set_apple_auth_revoke_tokens_updated_at()
returns trigger
language plpgsql
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

drop trigger if exists apple_auth_revoke_tokens_updated_at
  on public.apple_auth_revoke_tokens;

create trigger apple_auth_revoke_tokens_updated_at
before update on public.apple_auth_revoke_tokens
for each row
execute function public.set_apple_auth_revoke_tokens_updated_at();
