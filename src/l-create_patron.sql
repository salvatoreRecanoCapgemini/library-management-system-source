-- 1. Create a new patron
CREATE OR REPLACE PROCEDURE create_patron(
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_phone VARCHAR,
    p_birth_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO patrons (
        first_name, 
        last_name, 
        email, 
        phone, 
        membership_date, 
        status, 
        birth_date
    )
    VALUES (
        p_first_name, 
        p_last_name, 
        p_email, 
        p_phone, 
        CURRENT_DATE, 
        'ACTIVE', 
        p_birth_date
    );
END;
$$;
