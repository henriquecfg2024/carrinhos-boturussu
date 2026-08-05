# Plano de Rollback de Emergência em Produção

Caso ocorra qualquer falha crítica ou incompatibilidade durante as alterações da branch `feature/melhoria-idosos-pontos-apoio-full`, execute os passos abaixo para restaurar o sistema ao estado 100% funcional em menos de 2 minutos.

---

## Passo 1: Restaurar o Código Fonte no Git

No terminal da pasta do projeto (`Boturussu`), rode:

```bash
git checkout main
git reset --hard backup/versao-estavel-05-08-2026
git push origin main --force
```

---

## Passo 2: Restaurar o Banco de Dados no Supabase

1. Acesse o **Supabase Dashboard** do projeto (rwspmfowmodcervlbyfq).
2. Vá no menu **SQL Editor**.
3. Abra o arquivo `/backups/supabase_backup_05_08_2026.sql`.
4. Cole todo o conteúdo e clique em **Run**.

---

## Passo 3: Verificação de Retorno da Aplicação

1. Abra a URL da aplicação no navegador (ou PWA no celular).
2. Verifique se a tela de Login carrega normalmente.
3. Teste o login com uma conta de publicador e confirme se os agendamentos estão intactos.
