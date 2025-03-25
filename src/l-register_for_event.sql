-- 3. Register for event
CREATE OR REPLACE PROCEDURE register_for_event(
    p_event_id INTEGER,
    p_patron_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO event_registrations (
        event_id,
        patron_id,
        registration_date,
        attendance_status
    )
    VALUES (
        p_event_id,
        p_patron_id,
        CURRENT_TIMESTAMP,
        'REGISTERED'
    );
    
    UPDATE library_events 
    SET current_participants = current_participants + 1
    WHERE event_id = p_event_id;
END;
$$;
