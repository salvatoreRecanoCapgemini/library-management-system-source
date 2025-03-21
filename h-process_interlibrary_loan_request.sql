-- 2. Complex Inter-Library Loan Processing System
CREATE OR REPLACE PROCEDURE process_interlibrary_loan_request(
    p_requesting_branch_id INTEGER,
    p_patron_id INTEGER,
    p_book_title VARCHAR,
    p_isbn VARCHAR,
    p_providing_institution VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_patron_record RECORD;
    v_branch_record RECORD;
    v_existing_requests INTEGER;
    v_cost DECIMAL(10,2);
    v_ill_id INTEGER;
    v_status VARCHAR;
    v_expected_arrival DATE;
BEGIN
    -- Create temporary table for request validation
    CREATE TEMP TABLE request_validation AS
    WITH patron_status AS (
        SELECT 
            p.patron_id,
            p.status as patron_status,
            mp.max_loans,
            COUNT(DISTINCT l.loan_id) as active_loans,
            COUNT(DISTINCT ill.ill_id) as active_ill_requests,
            EXISTS (
                SELECT 1 FROM fines f 
                WHERE f.patron_id = p.patron_id 
                AND f.status = 'PENDING'
            ) has_pending_fines
        FROM patrons p
        JOIN patron_memberships pm ON p.patron_id = pm.patron_id AND pm.status = 'ACTIVE'
        JOIN membership_plans mp ON pm.plan_id = mp.plan_id
        LEFT JOIN loans l ON p.patron_id = l.patron_id AND l.status IN ('ACTIVE', 'OVERDUE')
        LEFT JOIN interlibrary_loans ill ON p.patron_id = ill.patron_id 
            AND ill.status IN ('REQUESTED', 'APPROVED', 'IN_TRANSIT')
        WHERE p.patron_id = p_patron_id
        GROUP BY p.patron_id, p.status, mp.max_loans
    )
    SELECT * FROM patron_status;

    -- Validate request
    SELECT * INTO v_patron_record FROM request_validation;
    
    IF v_patron_record.patron_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Patron account is not active';
    END IF;

    IF v_patron_record.has_pending_fines THEN
        RAISE EXCEPTION 'Patron has pending fines';
    END IF;

    IF v_patron_record.active_ill_requests >= 2 THEN
        RAISE EXCEPTION 'Maximum number of active inter-library loan requests reached';
    END IF;

    -- Calculate expected arrival and cost
    v_expected_arrival := CURRENT_DATE + INTERVAL '7 days';
    v_cost := 15.00; -- Base cost, could be calculated based on various factors

    -- Insert ILL request
    INSERT INTO interlibrary_loans (
        requesting_branch_id,
        providing_institution,
        book_title,
        isbn,
        patron_id,
        request_date,
        expected_arrival_date,
        cost,
        status,
        notes
    ) VALUES (
        p_requesting_branch_id,
        p_providing_institution,
        p_book_title,
        p_isbn,
        p_patron_id,
        CURRENT_TIMESTAMP,
        v_expected_arrival,
        v_cost,
        'REQUESTED',
        format('Initial request for %s from %s', p_book_title, p_providing_institution)
    ) RETURNING ill_id INTO v_ill_id;

    -- Create tracking record in audit_log
    INSERT INTO audit_log (
        table_name,
        record_id,
        action_type,
        action_timestamp,
        new_values
    ) VALUES (
        'interlibrary_loans',
        v_ill_id,
        'REQUEST',
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'patron_id', p_patron_id,
            'book_title', p_book_title,
            'providing_institution', p_providing_institution,
            'expected_arrival', v_expected_arrival,
            'cost', v_cost,
            'validation_data', row_to_json(v_patron_record)
        )
    );

    DROP TABLE request_validation;
END;
$$;
