-- 1. Generate Monthly Library Statistics Report
CREATE OR REPLACE PROCEDURE generate_monthly_statistics(
    p_year INTEGER,
    p_month INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
    v_result RECORD;
    v_stats JSONB;
BEGIN
    -- Set date range
    v_start_date := make_date(p_year, p_month, 1);
    v_end_date := v_start_date + interval '1 month' - interval '1 day';
    
    -- Create temporary table for statistics
    CREATE TEMP TABLE monthly_stats AS
    WITH loan_stats AS (
        SELECT 
            COUNT(*) as total_loans,
            COUNT(CASE WHEN status = 'OVERDUE' THEN 1 END) as overdue_loans,
            COUNT(DISTINCT patron_id) as active_borrowers
        FROM loans
        WHERE loan_date BETWEEN v_start_date AND v_end_date
    ),
    fine_stats AS (
        SELECT 
            SUM(amount) as total_fines,
            COUNT(CASE WHEN status = 'PAID' THEN 1 END) as paid_fines,
            COUNT(CASE WHEN status = 'PENDING' THEN 1 END) as pending_fines
        FROM fines
        WHERE issue_date BETWEEN v_start_date AND v_end_date
    ),
    book_stats AS (
        SELECT 
            COUNT(DISTINCT b.book_id) as books_in_circulation,
            SUM(b.available_copies) as total_available_copies,
            AVG(COALESCE(r.rating, 0)) as average_rating
        FROM books b
        LEFT JOIN book_reviews r ON b.book_id = r.book_id
        WHERE r.review_date BETWEEN v_start_date AND v_end_date
        OR r.review_date IS NULL
    ),
    event_stats AS (
        SELECT 
            COUNT(*) as total_events,
            SUM(current_participants) as total_participants,
            AVG(CAST(current_participants AS FLOAT) / NULLIF(max_participants, 0)) * 100 as avg_capacity_utilization
        FROM library_events
        WHERE event_date BETWEEN v_start_date AND v_end_date
    )
    SELECT * FROM loan_stats, fine_stats, book_stats, event_stats;

    -- Store results in audit_log
    SELECT * INTO v_result FROM monthly_stats;
    v_stats = row_to_json(v_result)::jsonb;
    
    INSERT INTO audit_log (
        table_name,
        record_id,
        action_type,
        action_timestamp,
        new_values
    ) VALUES (
        'monthly_statistics',
        extract(epoch from v_start_date)::integer,
        'INSERT',
        CURRENT_TIMESTAMP,
        v_stats
    );

    DROP TABLE monthly_stats;
END;
$$;
