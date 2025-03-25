-- 3. Automated Fine Management and Notification System
CREATE OR REPLACE PROCEDURE process_overdue_items()
LANGUAGE plpgsql
AS $$
DECLARE
    v_overdue_record RECORD;
    v_notification_text TEXT;
    v_fine_amount DECIMAL(10,2);
BEGIN
    -- Create temporary table for notifications
    CREATE TEMP TABLE notifications (
        patron_id INTEGER,
        email VARCHAR(100),
        message TEXT
    );

    -- Process overdue items
    FOR v_overdue_record IN (
        SELECT 
            l.loan_id,
            l.patron_id,
            l.book_id,
            l.due_date,
            b.title,
            p.email,
            p.first_name,
            CURRENT_DATE - l.due_date as days_overdue
        FROM loans l
        JOIN books b ON l.book_id = b.book_id
        JOIN patrons p ON l.patron_id = p.patron_id
        WHERE l.status = 'ACTIVE'
        AND l.due_date < CURRENT_DATE
        AND NOT EXISTS (
            SELECT 1 FROM fines f 
            WHERE f.loan_id = l.loan_id 
            AND f.issue_date = CURRENT_DATE
        )
    )
    LOOP
        -- Calculate fine amount
        v_fine_amount := v_overdue_record.days_overdue * 0.50;
        
        -- Create fine record
        INSERT INTO fines (
            patron_id,
            loan_id,
            amount,
            issue_date,
            due_date,
            status
        ) VALUES (
            v_overdue_record.patron_id,
            v_overdue_record.loan_id,
            v_fine_amount,
            CURRENT_DATE,
            CURRENT_DATE + 30,
            'PENDING'
        );

        -- Update loan status
        UPDATE loans 
        SET status = 'OVERDUE'
        WHERE loan_id = v_overdue_record.loan_id;

        -- Prepare notification
        v_notification_text := format(
            'Dear %s, the book "%s" is overdue by %s days. A fine of $%s has been issued.',
            v_overdue_record.first_name,
            v_overdue_record.title,
            v_overdue_record.days_overdue,
            v_fine_amount
        );

        -- Queue notification
        INSERT INTO notifications (patron_id, email, message)
        VALUES (v_overdue_record.patron_id, v_overdue_record.email, v_notification_text);
    END LOOP;

    -- Process notifications (in real system, would integrate with email service)
    -- For demonstration, we'll log them in audit_log
    INSERT INTO audit_log (
        table_name,
        record_id,
        action_type,
        action_timestamp,
        new_values
    )
    SELECT 
        'notifications',
        patron_id,
        'INSERT',
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'email', email,
            'message', message
        )
    FROM notifications;

    DROP TABLE notifications;
END;
$$;
