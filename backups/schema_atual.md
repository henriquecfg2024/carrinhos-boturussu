# Estrutura do Banco de Dados Supabase (Pre-Refatoração)
**Data:** 05/08/2026

> Documento histórico. As policies abaixo eram inseguras e não devem ser aplicadas.
> A configuração vigente deve ser criada por `supabase/migrations/08_auth_hardening.sql`.

## Tabela Atual: `app_store`
Atualmente o projeto utiliza a estrutura de chave-valor com sincronização em tempo real e fallback local:

```sql
CREATE TABLE IF NOT EXISTS public.app_store (
    key text PRIMARY KEY,
    data jsonb NOT NULL,
    updated_at timestamptz DEFAULT now()
);

-- Ativar RLS
ALTER TABLE public.app_store ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
-- Policies legadas removidas por 08_auth_hardening.sql.
```

### Chaves armazenadas no JSONB (`app_store`):
1. `users`: Lista de perfis de publicadores e administradores (`id`, `nome`, `telefone`, `senhaHash`, `role`, `congregacaoId`, `status`, `criadoEm`).
2. `carts`: Lista de carrinhos/locais de serviço (`id`, `nome`, `diasFunc`, `turnos`, `maxPub`, `minPub`, `congregacaoId`).
3. `schedules`: Lista de agendamentos (`id`, `cartId`, `date`, `slotId`, `pub1`, `pub2`, `pub3`, `waitingList`, `status`, `congregacaoId`).
4. `congregacoes`: Lista de congregações registradas.
5. `reports`: Relatórios mensais de horas/publicações.
6. `logs`: Histórico de auditoria de ações.
7. `config`: Parâmetros gerais da congregação.

---

## Novas Tabelas Relacionais a Serem Criadas (Fase 3):
- `support_points`
- `service_locations`
- `equipments`
- `responsibilities`
- `schedules` (Refatorada com FKs para os novos relacionamentos)
