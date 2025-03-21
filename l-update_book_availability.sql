-- 2. Update book availability
CREATE OR REPLACE PROCEDURE update_book_availability(
    p_book_id INTEGER,
    p_change INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE books 
    SET available_copies = available_copies + p_change
    WHERE book_id = p_book_id;
END;
$$;
