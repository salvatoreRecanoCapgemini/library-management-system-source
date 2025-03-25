-- 6. Complex Membership Plan Analysis and Optimization System
CREATE OR REPLACE PROCEDURE analyze_membership_plans(
    p_action VARCHAR,
    p_params JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_analysis_period_months INTEGER := 12;
    v_optimization_threshold DECIMAL := 0.15;
    v_plan_record RECORD;
BEGIN
    -- Create temporary table for membership analysis
    CREATE TEMP TABLE membership_metrics AS
    WITH plan_usage AS (
        SELECT 
            mp.plan_id,
            mp.name as plan_name,
            mp.price,
            mp.max_loans,
            mp.max_reservations,
            COUNT(DISTINCT pm.membership_id) as total_subscriptions,
            COUNT(DISTINCT CASE 
                WHEN pm.start_date >= CURRENT_DATE - INTERVAL '3 months' 
                THEN pm.membership_id 
            END) as recent_subscriptions,
            COUNT(DISTINCT CASE 
                WHEN pm.status = 'ACTIVE' 
                THEN pm.membership_id 
            END) as active_subscriptions,
            AVG(CASE 
                WHEN pm.status = 'CANCELLED' 
                THEN DATE_PART('day', pm.end_date - pm.start_date)
            END) as avg_subscription_duration,
            SUM(CASE 
                WHEN pm.payment_status = 'PAID' 
                THEN mp.price 
                ELSE 0 
            END) as total_revenue,
            jsonb_object_agg(
                DATE_TRUNC('month', pm.start_date)::date::text,
                COUNT(pm.membership_id)
            ) as subscription_trend
        FROM membership_plans mp
        LEFT JOIN patron_memberships pm ON mp.plan_id = pm.plan_id
        WHERE pm.start_date >= CURRENT_DATE - INTERVAL '12 months'
        GROUP BY mp.plan_id, mp.name, mp.price, mp.max_loans, mp.max_reservations
    ),
    plan_utilization AS (
        SELECT 
            pu.*,
            COUNT(DISTINCT l.loan_id) as total_loans,
            COUNT(DISTINCT r.reservation_id) as total_reservations,
            AVG(CAST(COUNT(DISTINCT l.loan_id) as DECIMAL) / 
                NULLIF(pu.max_loans * pu.active_subscriptions, 0)) as loan_utilization_rate,
            AVG(CAST(COUNT(DISTINCT r.reservation_id) as DECIMAL) / 
                NULLIF(pu.max_reservations * pu.active_subscriptions, 0)) as reservation_utilization_rate
        FROM plan_usage pu
        LEFT JOIN patron_memberships pm ON pu.plan_id = pm.plan_id
        LEFT JOIN loans l ON pm.patron_id = l.patron_id 
            AND l.loan_date BETWEEN pm.start_date AND COALESCE(pm.end_date, CURRENT_DATE)
        LEFT JOIN reservations r ON pm.patron_id = r.patron_id 
            AND r.reservation_date BETWEEN pm.start_date AND COALESCE(pm.end_date, CURRENT_DATE)
        GROUP BY pu.plan_id, pu.name, pu.price, pu.max_loans, pu.max_reservations,
                 pu.total_subscriptions, pu.recent_subscriptions, pu.active_subscriptions,
                 pu.avg_subscription_duration, pu.total_revenue, pu.subscription_trend
    )
    SELECT * FROM plan_utilization;

    CASE p_action
    WHEN 'ANALYZE_PERFORMANCE' THEN
        -- Create performance analysis recommendations
        CREATE TEMP TABLE performance_recommendations AS
        WITH plan_performance AS (
            SELECT 
                mm.*,
                CASE 
                    WHEN loan_utilization_rate < 0.3 THEN 'Underutilized loans'
                    WHEN loan_utilization_rate > 0.9 THEN 'High loan demand'
                    ELSE 'Optimal loan usage'
                END as loan_status,
                CASE 
                    WHEN reservation_utilization_rate < 0.3 THEN 'Underutilized reservations'
                    WHEN reservation_utilization_rate > 0.9 THEN 'High reservation demand'
                    ELSE 'Optimal reservation usage'
                END as reservation_status,
                CASE 
                    WHEN recent_subscriptions::DECIMAL / NULLIF(total_subscriptions, 0) < 0.15 
                    THEN 'Declining popularity'
                    WHEN recent_subscriptions::DECIMAL / NULLIF(total_subscriptions, 0) > 0.4 
                    THEN 'Growing popularity'
                    ELSE 'Stable popularity'
                END as popularity_trend
            FROM membership_metrics mm
        )
        SELECT * FROM plan_performance;

        -- Generate performance report
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'membership_analysis',
            plan_id,
            'PERFORMANCE_REPORT',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'plan_name', plan_name,
                'metrics', jsonb_build_object(
                    'total_subscriptions', total_subscriptions,
                    'active_subscriptions', active_subscriptions,
                    'avg_duration', avg_subscription_duration,
                    'total_revenue', total_revenue,
                    'loan_utilization', loan_utilization_rate,
                    'reservation_utilization', reservation_utilization_rate
                ),
                'status', jsonb_build_object(
                    'loans', loan_status,
                    'reservations', reservation_status,
                    'popularity', popularity_trend
                )
            )
        FROM performance_recommendations;

        DROP TABLE performance_recommendations;

    WHEN 'OPTIMIZE_PRICING' THEN
        -- Create pricing optimization recommendations
        CREATE TEMP TABLE pricing_recommendations AS
        WITH revenue_analysis AS (
            SELECT 
                mm.*,
                total_revenue::DECIMAL / NULLIF(total_subscriptions, 0) as revenue_per_subscription,
                total_loans::DECIMAL / NULLIF(total_subscriptions, 0) as loans_per_subscription,
                total_reservations::DECIMAL / NULLIF(total_subscriptions, 0) as reservations_per_subscription,
                CASE 
                    WHEN loan_utilization_rate > 0.8 AND price < 50 THEN 
                        LEAST(price * 1.2, price + 10)
                    WHEN loan_utilization_rate < 0.3 AND price > 20 THEN 
                        GREATEST(price * 0.8, price - 10)
                    ELSE price
                END as recommended_price
            FROM membership_metrics mm
        )
        SELECT 
            ra.*,
            CASE 
                WHEN ABS(recommended_price - price) / price > v_optimization_threshold 
                THEN 'Price adjustment recommended'
                ELSE 'Price is optimal'
            END as price_recommendation,
            CASE
                WHEN loan_utilization_rate > 0.8 THEN 'Consider increasing max_loans'
                WHEN loan_utilization_rate < 0.3 THEN 'Consider decreasing max_loans'
                ELSE 'Optimal loan limit'
            END as loan_limit_recommendation
        FROM revenue_analysis ra;

        -- Generate pricing recommendations
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'membership_pricing',
            plan_id,
            'PRICING_RECOMMENDATION',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'plan_name', plan_name,
                'current_price', price,
                'recommended_price', recommended_price,
                'price_recommendation', price_recommendation,
                'loan_limit_recommendation', loan_limit_recommendation,
                'metrics', jsonb_build_object(
                    'revenue_per_subscription', revenue_per_subscription,
                    'loans_per_subscription', loans_per_subscription,
                    'reservations_per_subscription', reservations_per_subscription
                )
            )
        FROM pricing_recommendations
        WHERE price_recommendation = 'Price adjustment recommended';

        DROP TABLE pricing_recommendations;

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
        'membership_analysis',
        0,
        p_action,
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'analysis_period_months', v_analysis_period_months,
            'optimization_threshold', v_optimization_threshold,
            'analyzed_plans', (SELECT COUNT(*) FROM membership_metrics)
        )
    );

    DROP TABLE membership_metrics;
END;
$$;
