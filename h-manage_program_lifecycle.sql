-- 3. Complex Library Program Management System
CREATE OR REPLACE PROCEDURE manage_program_lifecycle(
    p_program_id INTEGER,
    p_action VARCHAR,
    p_params JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_program RECORD;
    v_registration RECORD;
    v_session_dates JSONB;
    v_attendance_threshold INTEGER;
    v_notification_batch JSONB;
    v_current_capacity INTEGER;
    v_waitlist_count INTEGER;
BEGIN
    -- Create temporary table for program status tracking
    CREATE TEMP TABLE program_status AS
    WITH program_metrics AS (
        SELECT 
            lp.*,
            COUNT(DISTINCT pr.registration_id) as total_registrations,
            COUNT(DISTINCT CASE WHEN pr.payment_status = 'PAID' THEN pr.registration_id END) as paid_registrations,
            COUNT(DISTINCT CASE WHEN pr.completion_status = 'COMPLETED' THEN pr.registration_id END) as completed_participants,
            AVG(COALESCE(pr.feedback_rating, 0)) as avg_rating,
            jsonb_object_agg(
                COALESCE(pr.patron_id::text, 'none'),
                jsonb_build_object(
                    'attendance', pr.attendance_log,
                    'payment_status', pr.payment_status,
                    'completion_status', pr.completion_status
                )
            ) as participant_details
        FROM library_programs lp
        LEFT JOIN program_registrations pr ON lp.program_id = pr.program_id
        WHERE lp.program_id = p_program_id
        GROUP BY lp.program_id
    )
    SELECT * FROM program_metrics;

    SELECT * INTO v_program FROM program_status;
    
    CASE p_action
    WHEN 'START_PROGRAM' THEN
        IF v_program.status != 'PUBLISHED' THEN
            RAISE EXCEPTION 'Program must be in PUBLISHED status to start';
        END IF;

        IF v_program.paid_registrations < v_program.min_participants THEN
            -- Create waitlist notification batch
            INSERT INTO audit_log (
                table_name,
                record_id,
                action_type,
                action_timestamp,
                new_values
            )
            SELECT 
                'program_notifications',
                pr.registration_id,
                'CANCELLATION',
                CURRENT_TIMESTAMP,
                jsonb_build_object(
                    'message', format('Program %s has been cancelled due to insufficient registrations', v_program.name),
                    'refund_amount', v_program.cost
                )
            FROM program_registrations pr
            WHERE pr.program_id = p_program_id
            AND pr.payment_status = 'PAID';

            UPDATE library_programs
            SET status = 'CANCELLED'
            WHERE program_id = p_program_id;
            
            RAISE EXCEPTION 'Program cancelled due to insufficient registrations';
        END IF;

        -- Initialize session schedule
        v_session_dates := v_program.session_schedule;
        
        UPDATE library_programs
        SET status = 'IN_PROGRESS',
            session_schedule = v_session_dates
        WHERE program_id = p_program_id;

    WHEN 'RECORD_ATTENDANCE' THEN
        IF v_program.status != 'IN_PROGRESS' THEN
            RAISE EXCEPTION 'Cannot record attendance for program not in progress';
        END IF;

        -- Create temporary table for attendance processing
        CREATE TEMP TABLE attendance_records AS
        SELECT 
            pr.registration_id,
            pr.patron_id,
            pr.attendance_log,
            p.email,
            p.first_name,
            p.last_name
        FROM program_registrations pr
        JOIN patrons p ON pr.patron_id = p.patron_id
        WHERE pr.program_id = p_program_id
        AND pr.payment_status = 'PAID';

        -- Update attendance logs
        FOR v_registration IN SELECT * FROM attendance_records
        LOOP
            UPDATE program_registrations
            SET attendance_log = COALESCE(attendance_log, '{}'::jsonb) || 
                jsonb_build_object(
                    CURRENT_DATE::text,
                    COALESCE((p_params->>'attended')::boolean, false)
                )
            WHERE registration_id = v_registration.registration_id;

            -- Generate attendance notification
            INSERT INTO audit_log (
                table_name,
                record_id,
                action_type,
                action_timestamp,
                new_values
            ) VALUES (
                'attendance_tracking',
                v_registration.registration_id,
                'ATTENDANCE',
                CURRENT_TIMESTAMP,
                jsonb_build_object(
                    'email', v_registration.email,
                    'attended', COALESCE((p_params->>'attended')::boolean, false),
                    'session_date', CURRENT_DATE,
                    'program_name', v_program.name
                )
            );
        END LOOP;

        DROP TABLE attendance_records;

    WHEN 'COMPLETE_PROGRAM' THEN
        IF v_program.status != 'IN_PROGRESS' THEN
            RAISE EXCEPTION 'Cannot complete program not in progress';
        END IF;

        -- Calculate completion statistics
        v_attendance_threshold := (jsonb_array_length(v_program.session_schedule) * 0.7)::integer;

        -- Update completion status for participants
        WITH completion_summary AS (
            SELECT 
                pr.registration_id,
                pr.patron_id,
                (SELECT count(*) 
                 FROM jsonb_object_keys(pr.attendance_log) 
                 WHERE (pr.attendance_log->>jsonb_object_keys(pr.attendance_log))::boolean = true
                ) as sessions_attended
            FROM program_registrations pr
            WHERE pr.program_id = p_program_id
            AND pr.payment_status = 'PAID'
        )
        UPDATE program_registrations pr
        SET completion_status = 
            CASE 
                WHEN cs.sessions_attended >= v_attendance_threshold THEN 'COMPLETED'
                ELSE 'DROPPED'
            END
        FROM completion_summary cs
        WHERE pr.registration_id = cs.registration_id;

        -- Update program status
        UPDATE library_programs
        SET status = 'COMPLETED',
            end_date = CURRENT_DATE
        WHERE program_id = p_program_id;

    ELSE
        RAISE EXCEPTION 'Invalid action specified: %', p_action;
    END CASE;

    -- Log program state change
    INSERT INTO audit_log (
        table_name,
        record_id,
        action_type,
        action_timestamp,
        new_values
    ) VALUES (
        'library_programs',
        p_program_id,
        p_action,
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'program_metrics', row_to_json(v_program),
            'action_params', p_params,
            'result_status', 'SUCCESS'
        )
    );

    DROP TABLE program_status;
END;
$$;
