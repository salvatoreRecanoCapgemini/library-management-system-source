-- 3. Manage Event Capacity and Waitlist
CREATE OR REPLACE PROCEDURE manage_event_registration(
    p_event_id INTEGER,
    p_patron_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_participants INTEGER;
    v_current_participants INTEGER;
    v_is_registered BOOLEAN;
BEGIN
    -- Check if patron is already registered
    SELECT EXISTS (
        SELECT 1 FROM event_registrations 
        WHERE event_id = p_event_id AND patron_id = p_patron_id
    ) INTO v_is_registered;
    
    IF v_is_registered THEN
        RAISE EXCEPTION 'Patron already registered for this event';
    END IF;
    
    -- Get event capacity information
    SELECT max_participants, current_participants 
    INTO v_max_participants, v_current_participants
    FROM library_events 
    WHERE event_id = p_event_id;
    
    IF v_current_participants >= v_max_participants THEN
        -- Add to waitlist logic could be implemented here
        RAISE EXCEPTION 'Event is full';
    END IF;
    
    -- Register patron
    CALL register_for_event(p_event_id, p_patron_id);
END;
$$;
