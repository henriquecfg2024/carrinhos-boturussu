-- RESET_MASTER_USER.sql
-- Script para criar/resetar diretamente o usuário Administrador MASTER no Supabase Auth e Profiles.
-- Execute no SQL Editor do Supabase substituindo 'SUA_SENHA_AQUI' pela senha desejada.

create extension if not exists pgcrypto with schema extensions;

delete from public.profiles where telefone = '11920066472';
delete from auth.users where email = '11920066472@auth.app-carrinho.local';

with new_user as (
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    '11920066472@auth.app-carrinho.local',
    extensions.crypt('SUA_SENHA_AQUI', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nome":"Administrador Master","telefone":"11920066472","perfil":"master"}',
    now(),
    now(),
    '', '', '', ''
  )
  returning id
)
insert into public.profiles (id, nome, telefone, perfil, status, congregacao_id)
select id, 'Administrador Master', '11920066472', 'master', 'ativo', 'boturussu'
from new_user;
