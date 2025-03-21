-- 4. Add book review
CREATE OR REPLACE PROCEDURE add_book_review(
    p_book_id INTEGER,
    p_patron_id INTEGER,
    p_rating INTEGER,
    p_review_text TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO book_reviews (
        book_id,
        patron_id,
        rating,
        review_text,
        review_date,
        status
    )
    VALUES (
        p_book_id,
        p_patron_id,
        p_rating,
        p_review_text,
        CURRENT_TIMESTAMP,
        'PENDING'
    );
END;
$$;
