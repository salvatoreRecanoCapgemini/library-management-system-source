-- 5. Complex Patron Account Management
CREATE OR REPLACE PROCEDURE manage_patron_account(
    p_patron_id INTEGER,
    p_action VARCHAR,
    p_params JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_patron_record RECORD;
    v_outstanding_items RECORD;
    v_temp_status VARCHAR;
    v_notification_text TEXT;
BEGIN
    -- Create temporary table for account status
    CREATE TEMP TABLE account_status AS
    WITH patron_summary AS (
        SELECT 
            p.patron_id,
            p.status as current_status,
            p.email,
            p.first_name,
            p.last_name,
            COUNT(DISTINCT l.loan_id) as active_loans,
            COUNT(DISTINCT CASE WHEN l.status = 'OVERDUE' THEN l.loan_id END) as overdue_items,
            COUNT(DISTINCT CASE WHEN f.status = 'PENDING' THEN f.fine_id END) as unpaid_fines,
            SUM(CASE WHEN f.status = 'PENDING' THEN f.amount ELSE 0 END) as total_pending_fines,
            COUNT(DISTINCT er.registration_id) as event_registrations,
            MAX(l.due_date) as latest_due_date
        FROM patrons p
        LEFT JOIN loans l ON p.patron_id = l.patron_id AND l.status != 'RETURNED'
        LEFT JOIN fines f ON p.patron_id = f.patron_id
        LEFT JOIN event_registrations er ON p.patron_id = er.patron_id
        WHERE p.patron_id = p_patron_id
        GROUP BY p.patron_id, p.status, p.email, p.first_name, p.last_name
    )
    SELECT * FROM patron_summary;

    -- Get patron summary
    SELECT * INTO v_patron_record FROM account_status;

    CASE p_action
    WHEN 'SUSPEND' THEN
        IF v_patron_record.current_status = 'SUSPENDED' THEN
            RAISE EXCEPTION 'Account is already suspended';
        END IF;

        -- Create temporary table for active loans
        CREATE TEMP TABLE active_loans AS
        SELECT l.loan_id, b.title, l.due_date
        FROM loans l
        JOIN books b ON l.book_id = b.book_id
        WHERE l.patron_id = p_patron_id
        AND l.status = 'ACTIVE';

        -- Update patron status
        UPDATE patrons
        SET status = 'SUSPENDED'
        WHERE patron_id = p_patron_id;

        -- Cancel active registrations
        UPDATE event_registrations
        SET attendance_status = 'NO_SHOW'
        WHERE patron_id = p_patron_id
        AND attendance_status = 'REGISTERED';

        -- Generate notification
        v_notification_text := format(
            'Dear %s %s, your account has been suspended. Reason: %s. ' ||
            'You have %s overdue items and $%s in unpaid fines. ' ||
            'Please return all items and clear your fines to reactivate your account.',
            v_patron_record.first_name,
            v_patron_record.last_name,
            COALESCE(p_params->>'reason', 'Administrative action'),
            v_patron_record.overdue_items,
            v_patron_record.total_pending_fines
        );

        -- Log suspension and notification
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        ) VALUES (
            'patron_status',
            p_patron_id,
            'UPDATE',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'status', 'SUSPENDED',
                'reason', COALESCE(p_params->>'reason', 'Administrative action'),
                'overdue_items', v_patron_record.overdue_items,
                'unpaid_fines', v_patron_record.total_pending_fines,
                'notification', v_notification_text
            )
        );

        DROP TABLE active_loans;

    WHEN 'REACTIVATE' THEN
        IF v_patron_record.unpaid_fines > 0 THEN
            RAISE EXCEPTION 'Cannot reactivate account with unpaid fines: $%', v_patron_record.total_pending_fines;
        END IF;

        IF v_patron_record.overdue_items > 0 THEN
            RAISE EXCEPTION 'Cannot reactivate account with overdue items: %', v_patron_record.overdue_items;
        END IF;

        -- Create temporary table for reactivation history
        CREATE TEMP TABLE reactivation_history AS
        SELECT 
            action_timestamp,
            new_values->>'reason' as suspension_reason
        FROM audit_log
        WHERE table_name = 'patron_status'
        AND record_id = p_patron_id
        AND new_values->>'status' = 'SUSPENDED'
        ORDER BY action_timestamp DESC
        LIMIT 5;

        UPDATE patrons
        SET status = 'ACTIVE'
        WHERE patron_id = p_patron_id
        RETURNING status INTO v_temp_status;

        -- Log reactivation with history
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'patron_status',
            p_patron_id,
            'UPDATE',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'status', 'ACTIVE',
                'previous_suspensions', json_agg(row_to_json(rh))
            )
        FROM reactivation_history rh;

        DROP TABLE reactivation_history;

    WHEN 'AUDIT_ACTIVITY' THEN
        -- Create detailed activity report
        CREATE TEMP TABLE activity_report AS
        WITH loan_history AS (
            SELECT 
                'LOAN' as activity_type,
                l.loan_date as activity_date,
                b.title as details,
                l.status
            FROM loans l
            JOIN books b ON l.book_id = b.book_id
            WHERE l.patron_id = p_patron_id
        ),
        fine_history AS (
            SELECT 
                'FINE' as activity_type,
                f.issue_date as activity_date,
                format('$%s - %s', f.amount, f.status) as details,
                f.status
            FROM fines f
            WHERE f.patron_id = p_patron_id
        ),
        event_history AS (
            SELECT 
                'EVENT' as activity_type,
                le.event_date as activity_date,
                le.title as details,
                er.attendance_status as status
            FROM event_registrations er
            JOIN library_events le ON er.event_id = le.event_id
            WHERE er.patron_id = p_patron_id
        )
        SELECT * FROM loan_history
        UNION ALL SELECT * FROM fine_history
        UNION ALL SELECT * FROM event_history
        ORDER BY activity_date DESC;

        -- Log audit report
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'patron_audit',
            p_patron_id,
            'AUDIT',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'patron_summary', row_to_json(v_patron_record),
                'activity_report', json_agg(row_to_json(ar))
            )
        FROM activity_report ar;

        DROP TABLE activity_report;

    ELSE
        RAISE EXCEPTION 'Invalid action specified: %', p_action;
    END CASE;

    DROP TABLE account_status;
END;
$$;
