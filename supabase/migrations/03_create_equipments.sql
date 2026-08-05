-- 03_create_equipments.sql
CREATE TABLE IF NOT EXISTS public.equipments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz DEFAULT now(),
    name text NOT NULL,
    type text CHECK (type IN ('carrinho_grande', 'display_portatil')),
    current_support_point_id uuid REFERENCES public.support_points(id),
    photo_url text,
    status text DEFAULT 'disponivel',
    is_active boolean DEFAULT true
);

ALTER TABLE public.equipments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leitura publica equipments" ON public.equipments;
CREATE POLICY "Leitura publica equipments" ON public.equipments FOR SELECT USING (true);
DROP POLICY IF EXISTS "Escrita admin equipments" ON public.equipments;
CREATE POLICY "Escrita admin equipments" ON public.equipments FOR ALL USING (true);
