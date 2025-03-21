-- 2. Complex Book Recommendation System
CREATE OR REPLACE PROCEDURE generate_book_recommendations(
    p_patron_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cursor REFCURSOR;
    v_recommended_books TEMP TABLE;
BEGIN
    -- Create temporary table for recommendations
    CREATE TEMP TABLE recommended_books (
        book_id INTEGER,
        title VARCHAR(200),
        score DECIMAL(10,2)
    );

    -- Get patron's reading history and preferences
    WITH patron_history AS (
        SELECT DISTINCT b.category, b.author
        FROM loans l
        JOIN books b ON l.book_id = b.book_id
        WHERE l.patron_id = p_patron_id
        AND l.loan_date >= CURRENT_DATE - INTERVAL '1 year'
    ),
    patron_ratings AS (
        SELECT b.category, b.author, AVG(br.rating) as avg_rating
        FROM book_reviews br
        JOIN books b ON br.book_id = b.book_id
        WHERE br.patron_id = p_patron_id
        GROUP BY b.category, b.author
    ),
    similar_patrons AS (
        SELECT DISTINCT l2.patron_id
        FROM loans l1
        JOIN loans l2 ON l1.book_id = l2.book_id
        WHERE l1.patron_id = p_patron_id
        AND l2.patron_id != p_patron_id
    )
    INSERT INTO recommended_books
    SELECT 
        b.book_id,
        b.title,
        (
            CASE WHEN b.category IN (SELECT category FROM patron_history) THEN 2 ELSE 0 END +
            CASE WHEN b.author IN (SELECT author FROM patron_history) THEN 1.5 ELSE 0 END +
            COALESCE((SELECT avg_rating FROM patron_ratings WHERE category = b.category), 0) +
            (SELECT COUNT(*) FROM loans l WHERE l.book_id = b.book_id AND l.patron_id IN (SELECT patron_id FROM similar_patrons)) * 0.1
        ) as score
    FROM books b
    WHERE b.book_id NOT IN (
        SELECT book_id FROM loans WHERE patron_id = p_patron_id
    )
    AND b.available_copies > 0
    ORDER BY score DESC
    LIMIT 10;

    -- Create cursor for results
    OPEN v_cursor FOR SELECT * FROM recommended_books ORDER BY score DESC;
    
    -- Clean up
    DROP TABLE recommended_books;
END;
$$;
