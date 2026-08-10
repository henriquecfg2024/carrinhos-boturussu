-- 01_create_support_points.sql
CREATE TABLE IF NOT EXISTS public.support_points (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz DEFAULT now(),
    name text NOT NULL,
    responsible_name text,
    address text,
    photo_url text,
    whatsapp text,
    maps_url text,
    is_active boolean DEFAULT true,
    unavailable_until timestamptz,
    unavailable_reason text,
    fallback_point_id uuid REFERENCES public.support_points(id),
    is_deleted boolean DEFAULT false
);

ALTER TABLE public.support_points ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leitura publica support_points" ON public.support_points;
CREATE POLICY "Leitura publica support_points" ON public.support_points FOR SELECT USING (true);
-- Escrita administrativa é criada pela migration 08_auth_hardening.sql.
