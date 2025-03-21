-- 4. Complex Event Management System
CREATE OR REPLACE PROCEDURE manage_library_events(
    p_action VARCHAR,
    p_event_id INTEGER DEFAULT NULL,
    p_event_data JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_record RECORD;
    v_notification_cursor REFCURSOR;
    v_registrant RECORD;
BEGIN
    CASE p_action
    WHEN 'CANCEL_EVENT' THEN
        -- Create temporary table for affected registrants
        CREATE TEMP TABLE affected_registrants AS
        SELECT 
            er.registration_id,
            p.email,
            p.first_name,
            le.title as event_title,
            le.event_date
        FROM event_registrations er
        JOIN patrons p ON er.patron_id = p.patron_id
        JOIN library_events le ON er.event_id = le.event_id
        WHERE le.event_id = p_event_id
        AND er.attendance_status = 'REGISTERED';

        -- Update event status
        UPDATE library_events
        SET status = 'CANCELLED'
        WHERE event_id = p_event_id;

        -- Update registrations
        UPDATE event_registrations
        SET attendance_status = 'NO_SHOW'
        WHERE event_id = p_event_id;

        -- Process notifications
        FOR v_registrant IN SELECT * FROM affected_registrants
        LOOP
            -- In real system, would send actual notifications
            INSERT INTO audit_log (
                table_name,
                record_id,
                action_type,
                action_timestamp,
                new_values
            ) VALUES (
                'event_notifications',
                v_registrant.registration_id,
                'INSERT',
                CURRENT_TIMESTAMP,
                jsonb_build_object(
                    'email', v_registrant.email,
                    'message', format('Event "%s" scheduled for %s has been cancelled.',
                                    v_registrant.event_title, v_registrant.event_date)
                )
            );
        END LOOP;

        DROP TABLE affected_registrants;

    WHEN 'RESCHEDULE_EVENT' THEN
        -- Validate new date
        IF NOT (p_event_data ? 'new_date') THEN
            RAISE EXCEPTION 'New date must be provided for rescheduling';
        END IF;

        -- Create temporary table for conflict checking
        CREATE TEMP TABLE schedule_conflicts AS
        SELECT 
            er.patron_id,
            p.email,
            p.first_name
        FROM event_registrations er
        JOIN patrons p ON er.patron_id = p.patron_id
        JOIN library_events le ON er.event_id = le.event_id
        WHERE er.event_id != p_event_id
        AND le.event_date = (p_event_data->>'new_date')::timestamp;

        -- Update event date
        UPDATE library_events
        SET event_date = (p_event_data->>'new_date')::timestamp
        WHERE event_id = p_event_id
        RETURNING * INTO v_event_record;

        -- Notify affected patrons
        FOR v_registrant IN SELECT * FROM schedule_conflicts
        LOOP
            -- Log conflict notifications
            INSERT INTO audit_log (
                table_name,
                record_id,
                action_type,
                action_timestamp,
                new_values
            ) VALUES (
                'schedule_conflicts',
                v_registrant.patron_id,
                'INSERT',
                CURRENT_TIMESTAMP,
                jsonb_build_object(
                    'email', v_registrant.email,
                    'message', format('Event "%s" has been rescheduled to %s. You have a scheduling conflict.',
                                    v_event_record.title, v_event_record.event_date)
                )
            );
        END LOOP;

        DROP TABLE schedule_conflicts;

    ELSE
        RAISE EXCEPTION 'Invalid action specified';
    END CASE;
END;
$$;
