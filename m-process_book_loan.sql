-- 1. Process Book Loan
CREATE OR REPLACE PROCEDURE process_book_loan(
    p_patron_id INTEGER,
    p_book_id INTEGER,
    p_loan_days INTEGER DEFAULT 14
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available_copies INTEGER;
    v_patron_status VARCHAR;
    v_active_loans INTEGER;
BEGIN
    -- Check book availability
    SELECT available_copies INTO v_available_copies
    FROM books WHERE book_id = p_book_id;
    
    -- Check patron status
    SELECT status, (
        SELECT COUNT(*) FROM loans 
        WHERE patron_id = p_patron_id AND status = 'ACTIVE'
    ) INTO v_patron_status, v_active_loans
    FROM patrons WHERE patron_id = p_patron_id;
    
    IF v_available_copies <= 0 THEN
        RAISE EXCEPTION 'Book is not available for loan';
    END IF;
    
    IF v_patron_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Patron account is not active';
    END IF;
    
    IF v_active_loans >= 5 THEN
        RAISE EXCEPTION 'Patron has reached maximum number of loans';
    END IF;
    
    -- Create loan record
    INSERT INTO loans (
        patron_id, book_id, loan_date, due_date, status
    ) VALUES (
        p_patron_id,
        p_book_id,
        CURRENT_DATE,
        CURRENT_DATE + p_loan_days,
        'ACTIVE'
    );
    
    -- Update book availability
    CALL update_book_availability(p_book_id, -1);
END;
$$;
