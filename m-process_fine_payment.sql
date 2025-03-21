-- 5. Process Fine Payment
CREATE OR REPLACE PROCEDURE process_fine_payment(
    p_fine_id INTEGER,
    p_amount_paid DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount DECIMAL(10,2);
    v_remaining_amount DECIMAL(10,2);
BEGIN
    -- Get fine amount
    SELECT amount INTO v_total_amount
    FROM fines 
    WHERE fine_id = p_fine_id AND status = 'PENDING';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Valid unpaid fine not found';
    END IF;
    
    IF p_amount_paid < v_total_amount THEN
        v_remaining_amount := v_total_amount - p_amount_paid;
        -- Partial payment logic could be implemented here
        RAISE EXCEPTION 'Partial payments not supported';
    END IF;
    
    -- Process payment
    UPDATE fines 
    SET status = 'PAID',
        payment_date = CURRENT_DATE
    WHERE fine_id = p_fine_id;
END;
$$;
