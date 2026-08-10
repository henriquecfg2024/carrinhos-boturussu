-- 04_create_responsibilities.sql
CREATE TABLE IF NOT EXISTS public.responsibilities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz DEFAULT now(),
    role_key text UNIQUE NOT NULL,
    person_name text NOT NULL,
    whatsapp text,
    photo_url text,
    help_text text,
    display_order integer DEFAULT 0
);

ALTER TABLE public.responsibilities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leitura publica responsibilities" ON public.responsibilities;
CREATE POLICY "Leitura publica responsibilities" ON public.responsibilities FOR SELECT USING (true);
-- Escrita administrativa é criada pela migration 08_auth_hardening.sql.
