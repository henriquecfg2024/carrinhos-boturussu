-- ============================================================
-- SUPABASE DATABASE BACKUP - 05/08/2026
-- PROJETO: App Carrinho de Publicações Boturussu
-- ============================================================

-- 1. Tabela Principal (Store Key-Value de alta velocidade)
CREATE TABLE IF NOT EXISTS public.app_store (
    key text PRIMARY KEY,
    data jsonb NOT NULL,
    updated_at timestamptz DEFAULT now()
);

-- 2. Ativar Row Level Security
ALTER TABLE public.app_store ENABLE ROW LEVEL SECURITY;

-- 3. Políticas RLS
DROP POLICY IF EXISTS "Permitir leitura para todos" ON public.app_store;
CREATE POLICY "Permitir leitura para todos" ON public.app_store FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir escrita para todos" ON public.app_store;
CREATE POLICY "Permitir escrita para todos" ON public.app_store FOR ALL USING (true);

-- 4. Inserção de segurança / validação de tabela
INSERT INTO public.app_store (key, data, updated_at)
VALUES (
    'backup_info_05_08_2026', 
    '{"version": "v1.0-estavel-pre-refatoracao", "created_at": "2026-08-05T10:45:00Z", "status": "ok"}'::jsonb,
    now()
)
ON CONFLICT (key) DO UPDATE SET updated_at = now();
