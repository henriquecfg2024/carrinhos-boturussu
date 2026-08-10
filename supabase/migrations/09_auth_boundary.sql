-- 09_auth_boundary.sql
-- Fase 2: remove acesso anônimo às tabelas existentes sem interromper o
-- fluxo atual. Aplicar somente depois de publicar o frontend com Auth.
--
-- Esta fase é uma barreira de compatibilidade. A etapa seguinte deve migrar
-- bookings/waiting para linhas por usuário e aplicar RLS por registro.

-- app_store
drop policy if exists "Acesso público livre" on public.app_store;
drop policy if exists "app_store_public_read" on public.app_store;
drop policy if exists "app_store_authenticated_access" on public.app_store;
drop policy if exists "app_store_admin_access" on public.app_store;

create policy "app_store_public_read"
  on public.app_store for select to anon, authenticated
  using (key in ('carts', 'config', 'congregacoes', 'equipments', 'blocked'));

create policy "app_store_authenticated_access"
  on public.app_store for all to authenticated
  using (
    public.is_active_user()
    and (
      key in ('bookings', 'waiting')
      or public.can_access_report_key(key)
    )
  )
  with check (
    public.is_active_user()
    and (
      key in ('bookings', 'waiting')
      or public.can_access_report_key(key)
    )
  );

create policy "app_store_admin_access"
  on public.app_store for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Tabelas normalizadas existentes.
drop policy if exists "Acesso total" on public.agendamentos;
drop policy if exists "Acesso total" on public.waitlist;
drop policy if exists "Acesso total" on public.locais;
drop policy if exists "Acesso total" on public.logs;

create policy "agendamentos_active_users"
  on public.agendamentos for all to authenticated
  using (public.is_active_user())
  with check (public.is_active_user());

create policy "waitlist_active_users"
  on public.waitlist for all to authenticated
  using (public.is_active_user())
  with check (public.is_active_user());

create policy "locais_public_read"
  on public.locais for select to anon, authenticated
  using (true);

create policy "locais_admin_write"
  on public.locais for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "logs_admin_only"
  on public.logs for select to authenticated
  using (public.is_admin());

create policy "logs_admin_write"
  on public.logs for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
