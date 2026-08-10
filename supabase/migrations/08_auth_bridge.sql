-- 08_auth_bridge.sql
-- Fase 1 da migração: adiciona Supabase Auth sem apagar nem bloquear o banco
-- legado. A aplicação continua usando os dados existentes durante a transição.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  legacy_id text,
  nome text not null,
  telefone text not null unique,
  perfil text not null default 'publicador'
    check (perfil in ('publicador', 'administrador', 'master')),
  status text not null default 'pendente'
    check (status in ('pendente', 'ativo', 'inativo')),
  congregacao_id text not null default 'boturussu',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists legacy_id text;
create unique index if not exists profiles_legacy_id_key
  on public.profiles (legacy_id) where legacy_id is not null;

alter table public.profiles enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nome, telefone, congregacao_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nome', 'Usuário'),
    coalesce(new.raw_user_meta_data ->> 'telefone', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'congregacao_id', 'boturussu')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and status = 'ativo'
      and perfil in ('administrador', 'master')
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'ativo'
  );
$$;

revoke all on function public.is_active_user() from public;
grant execute on function public.is_active_user() to authenticated;

create or replace function public.can_access_report_key(p_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and p_key in (
        'report_' || id::text,
        'report_' || coalesce(legacy_id, ''),
        'report_cfg_' || id::text,
        'report_cfg_' || coalesce(legacy_id, '')
      )
  );
$$;

revoke all on function public.can_access_report_key(text) from public;
grant execute on function public.can_access_report_key(text) to authenticated;

drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert to authenticated
  with check (id = auth.uid() and perfil = 'publicador' and status = 'pendente');

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin"
  on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (
    public.is_admin()
    or (id = auth.uid() and perfil = 'publicador' and status = 'pendente')
  );

drop policy if exists "profiles_delete_admin" on public.profiles;
create policy "profiles_delete_admin"
  on public.profiles for delete to authenticated
  using (public.is_admin());

-- Nenhuma tabela existente é apagada ou tem seus dados removidos nesta fase.
-- O bloqueio das policies públicas será feito somente após o novo frontend
-- estar publicado e validado com usuários de teste.
