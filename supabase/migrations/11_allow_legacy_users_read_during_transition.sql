-- 11_allow_legacy_users_read_during_transition.sql
-- Permite leitura da chave 'users' na app_store durante a transição
-- para permitir que o login legado/fallback funcione no frontend caso a
-- Edge Function legacy-login ainda não tenha sido implantada no Supabase.

drop policy if exists "app_store_public_read" on public.app_store;

create policy "app_store_public_read"
  on public.app_store for select to anon, authenticated
  using (key in ('carts', 'config', 'congregacoes', 'equipments', 'blocked', 'users'));
