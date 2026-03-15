-- push worker vault setup
-- Supabase Dashboard > SQL Editor で実行
--
-- 既に同名 secret がある場合は delete -> create で入れ直す

delete from vault.secrets where name in ('project_url', 'publishable_key');

select vault.create_secret(
  'https://fkkvqxbzvysimylzedus.supabase.co',
  'project_url'
);

select vault.create_secret(
  '<YOUR_SUPABASE_ANON_KEY>',
  'publishable_key'
);

-- 確認
-- select name, decrypted_secret
-- from vault.decrypted_secrets
-- where name in ('project_url', 'publishable_key');
