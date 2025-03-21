-- 2. Process Book Return and Calculate Fines
CREATE OR REPLACE PROCEDURE process_book_return(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INTEGER;
    v_patron_id INTEGER;
    v_due_date DATE;
    v_days_overdue INTEGER;
    v_fine_amount DECIMAL(10,2);
BEGIN
    -- Get loan details
    SELECT book_id, patron_id, due_date 
    INTO v_book_id, v_patron_id, v_due_date
    FROM loans 
    WHERE loan_id = p_loan_id AND status = 'ACTIVE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active loan not found';
    END IF;
    
    -- Calculate overdue days and fine
    v_days_overdue := CURRENT_DATE - v_due_date;
    IF v_days_overdue > 0 THEN
        v_fine_amount := v_days_overdue * 0.50; -- $0.50 per day
        
        INSERT INTO fines (
            patron_id, loan_id, amount, issue_date, due_date, status
        ) VALUES (
            v_patron_id,
            p_loan_id,
            v_fine_amount,
            CURRENT_DATE,
            CURRENT_DATE + 30,
            'PENDING'
        );
    END IF;
    
    -- Update loan status
    UPDATE loans 
    SET status = 'RETURNED',
        return_date = CURRENT_DATE
    WHERE loan_id = p_loan_id;
    
    -- Update book availability
    CALL update_book_availability(v_book_id, 1);
END;
$$;
