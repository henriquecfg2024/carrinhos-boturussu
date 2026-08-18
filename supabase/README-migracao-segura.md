# Migração segura sem recadastro

## Ordem obrigatória

1. Faça backup privado do banco e valide a restauração.
2. Execute `migrations/08_auth_bridge.sql` no projeto Supabase de produção.
3. Publique a Edge Function `legacy-login` com `SUPABASE_SERVICE_ROLE_KEY` configurada como secret.
4. Publique o `index.html` atualizado.
5. Teste com um colaborador existente: o primeiro login deve usar o telefone e a senha atuais; os próximos devem usar Supabase Auth.
6. Confirme login, cadastro, consulta de agendamentos, criação/cancelamento e painel administrativo.
7. Somente depois execute `migrations/09_auth_boundary.sql`.

## Importante

- Não apagar `app_store.users` antes da migração dos colaboradores.
- Não compartilhar `SUPABASE_SERVICE_ROLE_KEY` no frontend ou no chat.
- A migration 09 é uma barreira de compatibilidade; `agendamentos` e `waitlist` ainda precisam ser normalizados por usuário para autorização granular.
- Após todos os usuários migrarem, remover a autenticação legada e apagar os dados de senha antigos em uma migration posterior.
