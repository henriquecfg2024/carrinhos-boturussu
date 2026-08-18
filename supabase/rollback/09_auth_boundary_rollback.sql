-- ROLLBACK EMERGENCIAL — usar somente se a aplicação parar após a fase 09.
-- Este arquivo reabre temporariamente o acesso público e deve ser revertido
-- assim que a versão corrigida estiver validada.

drop policy if exists "app_store_public_read" on public.app_store;
drop policy if exists "app_store_authenticated_access" on public.app_store;
drop policy if exists "app_store_admin_access" on public.app_store;
create policy "Acesso público livre" on public.app_store
  for all to public using (true) with check (true);

drop policy if exists "agendamentos_active_users" on public.agendamentos;
create policy "Acesso total" on public.agendamentos
  for all to public using (true) with check (true);

drop policy if exists "waitlist_active_users" on public.waitlist;
create policy "Acesso total" on public.waitlist
  for all to public using (true) with check (true);

drop policy if exists "locais_public_read" on public.locais;
drop policy if exists "locais_admin_write" on public.locais;
create policy "Acesso total" on public.locais
  for all to public using (true) with check (true);

drop policy if exists "logs_admin_only" on public.logs;
drop policy if exists "logs_admin_write" on public.logs;
create policy "Acesso total" on public.logs
  for all to public using (true) with check (true);
