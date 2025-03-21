-- 4. Extend Loan Period
CREATE OR REPLACE PROCEDURE extend_loan_period(
    p_loan_id INTEGER,
    p_extension_days INTEGER DEFAULT 7
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_extensions INTEGER;
    v_has_reservations BOOLEAN;
    v_book_id INTEGER;
BEGIN
    -- Get loan details
    SELECT extensions_count, book_id 
    INTO v_current_extensions, v_book_id
    FROM loans 
    WHERE loan_id = p_loan_id AND status = 'ACTIVE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active loan not found';
    END IF;
    
    IF v_current_extensions >= 2 THEN
        RAISE EXCEPTION 'Maximum extensions reached';
    END IF;
    
    -- Check for reservations
    SELECT EXISTS (
        SELECT 1 FROM reservations 
        WHERE book_id = v_book_id AND status = 'PENDING'
    ) INTO v_has_reservations;
    
    IF v_has_reservations THEN
        RAISE EXCEPTION 'Book has pending reservations';
    END IF;
    
    -- Extend loan
    UPDATE loans 
    SET due_date = due_date + p_extension_days,
        extensions_count = extensions_count + 1
    WHERE loan_id = p_loan_id;
END;
$$;
