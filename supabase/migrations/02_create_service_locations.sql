-- 02_create_service_locations.sql
CREATE TABLE IF NOT EXISTS public.service_locations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz DEFAULT now(),
    name text NOT NULL,
    type text,
    maps_url text,
    photo_url text,
    default_support_point_id uuid REFERENCES public.support_points(id),
    default_equipment_id uuid,
    is_active boolean DEFAULT true
);

ALTER TABLE public.service_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leitura publica service_locations" ON public.service_locations;
CREATE POLICY "Leitura publica service_locations" ON public.service_locations FOR SELECT USING (true);
DROP POLICY IF EXISTS "Escrita admin service_locations" ON public.service_locations;
CREATE POLICY "Escrita admin service_locations" ON public.service_locations FOR ALL USING (true);
