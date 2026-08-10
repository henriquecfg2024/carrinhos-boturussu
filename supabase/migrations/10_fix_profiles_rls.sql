-- 10_fix_profiles_rls.sql
-- Fase 2.1: Permite que usuários ativos atualizem seus próprios dados (nome/telefone)
-- mantendo perfil como 'publicador' e status válido, sem auto-promoção.

drop policy if exists "profiles_update_own_or_admin" on public.profiles;

create policy "profiles_update_own_or_admin"
  on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (
    public.is_admin()
    or (
      id = auth.uid()
      and perfil = 'publicador'
      and status in ('pendente', 'ativo')
    )
  );
