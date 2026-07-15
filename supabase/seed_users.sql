-- Local-only auth users, seeded on `supabase db reset`. Plain SQL (runs via
-- the CLI's SQL driver, so no psql meta-commands). Passwords are bcrypt-
-- hashed via pgcrypto the same way GoTrue stores them. Inserting into
-- auth.users fires handle_new_user(), which creates the matching profiles
-- row (username taken from raw_user_meta_data).
--
-- Throwaway dev credentials - never use in prod. Both use password 123.
--   dev@local.test    normal user
--   admin@local.test  editor/admin (flags bit 0 set below)

-- confirmation_token / recovery_token / email_change* must be '' (not
-- NULL) or GoTrue's schema scan errors with "Database error querying
-- schema" on login.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values
  ('00000000-0000-0000-0000-000000000000',
   '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'dev@local.test',
   crypt('123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"username":"dev"}',
   now(), now(),
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000',
   '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'admin@local.test',
   crypt('123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"username":"admin"}',
   now(), now(),
   '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider, created_at, updated_at
) values
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111',
   '11111111-1111-1111-1111-111111111111',
   '{"sub":"11111111-1111-1111-1111-111111111111","email":"dev@local.test"}',
   'email', now(), now()),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222',
   '22222222-2222-2222-2222-222222222222',
   '{"sub":"22222222-2222-2222-2222-222222222222","email":"admin@local.test"}',
   'email', now(), now())
on conflict do nothing;

-- flags bit 0 = can edit tricks (admin/editor).
update profiles set flags = flags | 1
where id = '22222222-2222-2222-2222-222222222222';
