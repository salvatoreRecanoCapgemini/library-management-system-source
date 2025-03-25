-- 5. Complex Collection Management and Analysis System
CREATE OR REPLACE PROCEDURE analyze_and_manage_collections(
    p_collection_id INTEGER DEFAULT NULL,
    p_action VARCHAR,
    p_params JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_collection_record RECORD;
    v_analysis_period_months INTEGER := 12;
    v_popularity_threshold DECIMAL := 0.7;
    v_recommendation_count INTEGER := 0;
BEGIN
    -- Create temporary table for collection analysis
    CREATE TEMP TABLE collection_metrics AS
    WITH collection_stats AS (
        SELECT 
            bc.collection_id,
            bc.name as collection_name,
            bci.book_id,
            b.title,
            b.isbn,
            b.publication_year,
            COUNT(DISTINCT l.loan_id) as total_loans,
            COUNT(DISTINCT CASE 
                WHEN l.loan_date >= CURRENT_DATE - INTERVAL '3 months' 
                THEN l.loan_id 
            END) as recent_loans,
            AVG(COALESCE(br.rating, 0)) as avg_rating,
            COUNT(DISTINCT br.review_id) as review_count,
            jsonb_object_agg(
                COALESCE(b.category, 'uncategorized'),
                COUNT(DISTINCT l.loan_id)
            ) as category_distribution
        FROM book_collections bc
        JOIN book_collection_items bci ON bc.collection_id = bci.collection_id
        JOIN books b ON bci.book_id = b.book_id
        LEFT JOIN loans l ON b.book_id = l.book_id
        LEFT JOIN book_reviews br ON b.book_id = br.book_id
        WHERE (p_collection_id IS NULL OR bc.collection_id = p_collection_id)
        GROUP BY bc.collection_id, bc.name, bci.book_id, b.title, b.isbn, b.publication_year
    ),
    collection_popularity AS (
        SELECT 
            cs.*,
            PERCENT_RANK() OVER (PARTITION BY collection_id ORDER BY total_loans) as popularity_rank,
            PERCENT_RANK() OVER (PARTITION BY collection_id ORDER BY avg_rating) as rating_rank
        FROM collection_stats cs
    )
    SELECT * FROM collection_popularity;

    CASE p_action
    WHEN 'ANALYZE_PERFORMANCE' THEN
        -- Create performance analysis recommendations
        CREATE TEMP TABLE performance_recommendations AS
        WITH underperforming_items AS (
            SELECT 
                cm.*,
                CASE 
                    WHEN popularity_rank < 0.3 AND rating_rank < 0.3 THEN 'Consider removal'
                    WHEN popularity_rank < 0.3 AND rating_rank >= 0.3 THEN 'Needs promotion'
                    WHEN popularity_rank >= 0.3 AND rating_rank < 0.3 THEN 'Quality concerns'
                    ELSE 'Performing well'
                END as recommendation,
                CASE 
                    WHEN recent_loans = 0 THEN 'No recent activity'
                    WHEN recent_loans < 3 THEN 'Low activity'
                    ELSE 'Active'
                END as activity_status
            FROM collection_metrics cm
        )
        SELECT * FROM underperforming_items
        WHERE recommendation != 'Performing well';

        -- Generate performance report
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'collection_analysis',
            collection_id,
            'PERFORMANCE_REPORT',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'collection_name', collection_name,
                'book_title', title,
                'recommendation', recommendation,
                'activity_status', activity_status,
                'metrics', jsonb_build_object(
                    'total_loans', total_loans,
                    'recent_loans', recent_loans,
                    'avg_rating', avg_rating,
                    'popularity_rank', popularity_rank,
                    'rating_rank', rating_rank
                )
            )
        FROM performance_recommendations;

        DROP TABLE performance_recommendations;

    WHEN 'GENERATE_ACQUISITION_RECOMMENDATIONS' THEN
        -- Create temporary table for acquisition analysis
        CREATE TEMP TABLE acquisition_recommendations AS
        WITH category_performance AS (
            SELECT 
                collection_id,
                collection_name,
                jsonb_object_keys(category_distribution) as category,
                (category_distribution->>jsonb_object_keys(category_distribution))::integer as category_loans
            FROM collection_metrics
        ),
        category_gaps AS (
            SELECT 
                cp.collection_id,
                cp.collection_name,
                cp.category,
                cp.category_loans,
                PERCENT_RANK() OVER (PARTITION BY cp.collection_id ORDER BY cp.category_loans) as category_rank,
                COUNT(*) OVER (PARTITION BY cp.collection_id, cp.category) as category_item_count
            FROM category_performance cp
        )
        SELECT 
            cg.*,
            CASE 
                WHEN category_rank < 0.3 AND category_item_count < 5 THEN 'High priority acquisition'
                WHEN category_rank < 0.5 AND category_item_count < 10 THEN 'Consider expansion'
                ELSE 'Adequate coverage'
            END as recommendation
        FROM category_gaps cg
        WHERE category_rank < 0.5;

        -- Generate acquisition recommendations
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'collection_acquisition',
            collection_id,
            'ACQUISITION_RECOMMENDATION',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'collection_name', collection_name,
                'category', category,
                'current_items', category_item_count,
                'recommendation', recommendation,
                'category_performance', jsonb_build_object(
                    'loans', category_loans,
                    'rank', category_rank
                )
            )
        FROM acquisition_recommendations
        WHERE recommendation != 'Adequate coverage';

        DROP TABLE acquisition_recommendations;

    WHEN 'REBALANCE_COLLECTION' THEN
        -- Create temporary table for rebalancing analysis
        CREATE TEMP TABLE rebalancing_recommendations AS
        WITH branch_distribution AS (
            SELECT 
                cm.collection_id,
                cm.collection_name,
                cm.book_id,
                cm.title,
                bi.branch_id,
                bi.available_copies,
                bi.total_copies,
                lb.name as branch_name,
                ROW_NUMBER() OVER (PARTITION BY cm.book_id ORDER BY bi.available_copies) as stock_rank
            FROM collection_metrics cm
            JOIN branch_inventory bi ON cm.book_id = bi.book_id
            JOIN library_branches lb ON bi.branch_id = lb.branch_id
        )
        SELECT 
            bd.*,
            CASE 
                WHEN stock_rank = 1 AND available_copies < 2 THEN 'Transfer needed'
                WHEN stock_rank > 1 AND available_copies > 5 THEN 'Excess stock'
                ELSE 'Balanced'
            END as rebalance_action
        FROM branch_distribution bd;

        -- Generate rebalancing recommendations
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'collection_rebalancing',
            collection_id,
            'REBALANCE_RECOMMENDATION',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'collection_name', collection_name,
                'book_title', title,
                'branch_name', branch_name,
                'current_stock', available_copies,
                'recommendation', rebalance_action
            )
        FROM rebalancing_recommendations
        WHERE rebalance_action != 'Balanced';

        DROP TABLE rebalancing_recommendations;

    ELSE
        RAISE EXCEPTION 'Invalid action specified: %', p_action;
    END CASE;

    -- Log analysis completion
    INSERT INTO audit_log (
        table_name,
        record_id,
        action_type,
        action_timestamp,
        new_values
    ) VALUES (
        'collection_management',
        COALESCE(p_collection_id, 0),
        p_action,
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'analysis_period_months', v_analysis_period_months,
            'popularity_threshold', v_popularity_threshold,
            'recommendation_count', v_recommendation_count
        )
    );

    DROP TABLE collection_metrics;
END;
$$;
