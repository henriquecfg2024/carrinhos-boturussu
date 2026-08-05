-- 05_update_schedules.sql
ALTER TABLE public.schedules
    ADD COLUMN IF NOT EXISTS service_location_id uuid REFERENCES public.service_locations(id),
    ADD COLUMN IF NOT EXISTS equipment_id uuid REFERENCES public.equipments(id),
    ADD COLUMN IF NOT EXISTS support_point_id uuid REFERENCES public.support_points(id),
    ADD COLUMN IF NOT EXISTS effective_support_point_id uuid REFERENCES public.support_points(id);
