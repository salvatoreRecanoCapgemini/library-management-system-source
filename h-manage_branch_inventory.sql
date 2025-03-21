-- 4. Complex Branch Inventory Management System
CREATE OR REPLACE PROCEDURE manage_branch_inventory(
    p_branch_id INTEGER,
    p_action VARCHAR,
    p_params JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inventory_record RECORD;
    v_threshold_config JSONB;
    v_transfer_batch JSONB;
    v_audit_data JSONB;
    v_discrepancy_count INTEGER := 0;
BEGIN
    -- Initialize threshold configuration
    v_threshold_config := jsonb_build_object(
        'low_stock_threshold', 3,
        'reorder_point', 5,
        'max_stock', 20,
        'critical_damage_threshold', 0.2
    );

    -- Create temporary table for inventory processing
    CREATE TEMP TABLE inventory_status AS
    WITH current_inventory AS (
        SELECT 
            bi.*,
            b.title,
            b.isbn,
            b.category,
            COUNT(l.loan_id) as active_loans,
            COUNT(CASE WHEN l.status = 'OVERDUE' THEN 1 END) as overdue_loans
        FROM branch_inventory bi
        JOIN books b ON bi.book_id = b.book_id
        LEFT JOIN loans l ON b.book_id = l.book_id 
            AND l.status IN ('ACTIVE', 'OVERDUE')
        WHERE bi.branch_id = p_branch_id
        GROUP BY bi.inventory_id, bi.branch_id, bi.book_id, b.title, b.isbn, b.category
    )
    SELECT * FROM current_inventory;

    CASE p_action
    WHEN 'AUDIT_INVENTORY' THEN
        -- Create temporary table for audit results
        CREATE TEMP TABLE audit_results AS
        SELECT 
            i.*,
            COALESCE((p_params->>'actual_count')::integer, 0) as actual_count,
            ABS(COALESCE((p_params->>'actual_count')::integer, 0) - i.available_copies) as discrepancy
        FROM inventory_status i;

        -- Process discrepancies
        FOR v_inventory_record IN SELECT * FROM audit_results WHERE discrepancy > 0
        LOOP
            v_discrepancy_count := v_discrepancy_count + 1;
            
            -- Update inventory record
            UPDATE branch_inventory
            SET 
                available_copies = COALESCE((p_params->>'actual_count')::integer, 0),
                last_inventory_date = CURRENT_TIMESTAMP,
                status = CASE 
                    WHEN COALESCE((p_params->>'actual_count')::integer, 0) = 0 THEN 'OUT_OF_STOCK'
                    WHEN COALESCE((p_params->>'actual_count')::integer, 0) <= (v_threshold_config->>'low_stock_threshold')::integer THEN 'LOW_STOCK'
                    ELSE 'ACTIVE'
                END
            WHERE inventory_id = v_inventory_record.inventory_id;

            -- Log discrepancy
            INSERT INTO audit_log (
                table_name,
                record_id,
                action_type,
                action_timestamp,
                new_values
            ) VALUES (
                'inventory_audit',
                v_inventory_record.inventory_id,
                'DISCREPANCY',
                CURRENT_TIMESTAMP,
                jsonb_build_object(
                    'book_title', v_inventory_record.title,
                    'expected_count', v_inventory_record.available_copies,
                    'actual_count', COALESCE((p_params->>'actual_count')::integer, 0),
                    'discrepancy', v_inventory_record.discrepancy
                )
            );
        END LOOP;

        DROP TABLE audit_results;

    WHEN 'PROCESS_DAMAGES' THEN
        -- Process damaged items
        UPDATE branch_inventory
        SET 
            damaged_copies = damaged_copies + COALESCE((p_params->>'damaged_count')::integer, 0),
            available_copies = available_copies - COALESCE((p_params->>'damaged_count')::integer, 0),
            status = CASE 
                WHEN (damaged_copies + COALESCE((p_params->>'damaged_count')::integer, 0))::float / total_copies::float 
                    >= (v_threshold_config->>'critical_damage_threshold')::float 
                THEN 'DISCONTINUED'
                ELSE status
            END
        WHERE inventory_id = (p_params->>'inventory_id')::integer;

    WHEN 'REORDER_ANALYSIS' THEN
        -- Create reorder recommendations
        CREATE TEMP TABLE reorder_recommendations AS
        SELECT 
            i.*,
            CASE 
                WHEN i.available_copies <= (v_threshold_config->>'reorder_point')::integer 
                THEN (v_threshold_config->>'max_stock')::integer - i.available_copies
                ELSE 0
            END as recommended_order_quantity
        FROM inventory_status i
        WHERE i.status IN ('ACTIVE', 'LOW_STOCK');

        -- Generate reorder report
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        )
        SELECT 
            'inventory_reorder',
            inventory_id,
            'REORDER_RECOMMENDATION',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'book_title', title,
                'current_stock', available_copies,
                'recommended_order', recommended_order_quantity,
                'category', category
            )
        FROM reorder_recommendations
        WHERE recommended_order_quantity > 0;

        DROP TABLE reorder_recommendations;

    ELSE
        RAISE EXCEPTION 'Invalid action specified: %', p_action;
    END CASE;

    -- Log final inventory state
    INSERT INTO audit_log (
        table_name,
        record_id,
        action_type,
        action_timestamp,
        new_values
    ) VALUES (
        'branch_inventory',
        p_branch_id,
        p_action,
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'action', p_action,
            'params', p_params,
            'discrepancies_found', v_discrepancy_count,
            'threshold_config', v_threshold_config
        )
    );

    DROP TABLE inventory_status;
END;
$$;
