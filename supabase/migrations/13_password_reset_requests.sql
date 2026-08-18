-- 13_password_reset_requests.sql
-- Public password reset requests for publishers. The public form can only
-- create pending requests; only admins can read or conclude them.

create extension if not exists pgcrypto;

create table if not exists public.password_reset_requests (
  id uuid primary key default gen_random_uuid(),
  telefone text not null,
  telefone_normalizado text not null,
  status text not null default 'pendente'
    check (status in ('pendente', 'concluido')),
  created_at timestamptz not null default now(),
  concluido_at timestamptz null,
  concluido_por uuid null references auth.users(id) on delete set null
);

create or replace function public.set_password_reset_phone_normalized()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.telefone_normalizado := regexp_replace(coalesce(new.telefone, ''), '[^0-9]', '', 'g');
  return new;
end;
$$;

drop trigger if exists password_reset_requests_normalize_phone
  on public.password_reset_requests;

create trigger password_reset_requests_normalize_phone
  before insert or update of telefone
  on public.password_reset_requests
  for each row
  execute function public.set_password_reset_phone_normalized();

create index if not exists password_reset_requests_phone_status_created_idx
  on public.password_reset_requests (telefone_normalizado, status, created_at desc);

create unique index if not exists password_reset_one_pending_per_phone
  on public.password_reset_requests (telefone_normalizado)
  where status = 'pendente';

alter table public.password_reset_requests enable row level security;

drop policy if exists "password_reset_public_insert_pending"
  on public.password_reset_requests;
create policy "password_reset_public_insert_pending"
  on public.password_reset_requests for insert to anon, authenticated
  with check (
    status = 'pendente'
    and concluido_at is null
    and concluido_por is null
    and regexp_replace(coalesce(telefone, ''), '[^0-9]', '', 'g') ~ '^[0-9]{10,11}$'
  );

drop policy if exists "password_reset_admin_select"
  on public.password_reset_requests;
create policy "password_reset_admin_select"
  on public.password_reset_requests for select to authenticated
  using (public.is_admin());

drop policy if exists "password_reset_admin_update"
  on public.password_reset_requests;
create policy "password_reset_admin_update"
  on public.password_reset_requests for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant insert on public.password_reset_requests to anon, authenticated;
grant select, update on public.password_reset_requests to authenticated;
