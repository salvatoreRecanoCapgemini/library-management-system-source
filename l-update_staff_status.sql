-- 5. Update staff status
CREATE OR REPLACE PROCEDURE update_staff_status(
    p_staff_id INTEGER,
    p_new_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE staff 
    SET status = p_new_status
    WHERE staff_id = p_staff_id;
END;
$$;
