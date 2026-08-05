-- 06_function_get_effective_support_point.sql
CREATE OR REPLACE FUNCTION public.get_effective_support_point(
    p_service_location_id uuid,
    p_datetime timestamptz DEFAULT now()
) RETURNS uuid AS $$
DECLARE
    v_default_point_id uuid;
    v_curr_point_id uuid;
    v_unav_until timestamptz;
    v_fallback_id uuid;
    v_depth integer := 0;
BEGIN
    SELECT default_support_point_id INTO v_default_point_id
    FROM public.service_locations
    WHERE id = p_service_location_id;

    IF v_default_point_id IS NULL THEN
        RETURN NULL;
    END IF;

    v_curr_point_id := v_default_point_id;

    WHILE v_curr_point_id IS NOT NULL AND v_depth < 3 LOOP
        SELECT unavailable_until, fallback_point_id
        INTO v_unav_until, v_fallback_id
        FROM public.support_points
        WHERE id = v_curr_point_id AND is_active = true AND is_deleted = false;

        IF v_unav_until IS NOT NULL AND v_unav_until > p_datetime THEN
            IF v_fallback_id IS NOT NULL AND v_fallback_id <> v_curr_point_id THEN
                v_curr_point_id := v_fallback_id;
                v_depth := v_depth + 1;
            ELSE
                EXIT;
            END IF;
        ELSE
            RETURN v_curr_point_id;
        END IF;
    END LOOP;

    RETURN v_default_point_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
