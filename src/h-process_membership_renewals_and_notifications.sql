-- 1. Complex Membership Management and Auto-Renewal Procedure
CREATE OR REPLACE PROCEDURE process_membership_renewals_and_notifications()
LANGUAGE plpgsql
AS $$
DECLARE
    v_membership RECORD;
    v_new_membership_id INTEGER;
    v_notification_text TEXT;
    v_payment_status VARCHAR;
BEGIN
    -- Create temporary table for processing renewals
    CREATE TEMP TABLE membership_renewals AS
    WITH expiring_memberships AS (
        SELECT 
            pm.membership_id,
            pm.patron_id,
            pm.plan_id,
            pm.end_date,
            pm.auto_renewal,
            mp.price,
            mp.duration_months,
            p.email,
            p.first_name,
            p.last_name,
            EXISTS (
                SELECT 1 FROM fines f 
                WHERE f.patron_id = pm.patron_id 
                AND f.status = 'PENDING'
            ) has_pending_fines,
            (
                SELECT COUNT(*) 
                FROM loans l 
                WHERE l.patron_id = pm.patron_id 
                AND l.status = 'OVERDUE'
            ) overdue_items_count
        FROM patron_memberships pm
        JOIN membership_plans mp ON pm.plan_id = mp.plan_id
        JOIN patrons p ON pm.patron_id = p.patron_id
        WHERE pm.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
        AND pm.status = 'ACTIVE'
    )
    SELECT * FROM expiring_memberships;

    -- Process each expiring membership
    FOR v_membership IN SELECT * FROM membership_renewals
    LOOP
        -- Handle auto-renewal cases
        IF v_membership.auto_renewal AND NOT v_membership.has_pending_fines AND v_membership.overdue_items_count = 0 THEN
            -- Attempt payment processing (simplified for demonstration)
            v_payment_status := CASE 
                WHEN random() > 0.1 THEN 'PAID' -- 90% success rate
                ELSE 'FAILED'
            END;

            IF v_payment_status = 'PAID' THEN
                -- Create new membership period
                INSERT INTO patron_memberships (
                    patron_id,
                    plan_id,
                    start_date,
                    end_date,
                    payment_status,
                    payment_method,
                    payment_reference,
                    auto_renewal,
                    status
                ) VALUES (
                    v_membership.patron_id,
                    v_membership.plan_id,
                    v_membership.end_date + 1,
                    v_membership.end_date + 1 + (v_membership.duration_months * 30),
                    'PAID',
                    'AUTO_RENEWAL',
                    'AR-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
                    true,
                    'ACTIVE'
                ) RETURNING membership_id INTO v_new_membership_id;

                -- Update old membership
                UPDATE patron_memberships
                SET status = 'EXPIRED'
                WHERE membership_id = v_membership.membership_id;

                v_notification_text := format(
                    'Dear %s %s, your membership has been automatically renewed. New expiration date: %s',
                    v_membership.first_name,
                    v_membership.last_name,
                    v_membership.end_date + 1 + (v_membership.duration_months * 30)
                );
            ELSE
                v_notification_text := format(
                    'Dear %s %s, we could not process your automatic membership renewal. Please update your payment information.',
                    v_membership.first_name,
                    v_membership.last_name
                );
            END IF;
        ELSE
            -- Prepare notification for manual renewal
            v_notification_text := format(
                'Dear %s %s, your membership expires on %s. Please renew your membership to continue enjoying our services.',
                v_membership.first_name,
                v_membership.last_name,
                v_membership.end_date
            );
        END IF;

        -- Log notification
        INSERT INTO audit_log (
            table_name,
            record_id,
            action_type,
            action_timestamp,
            new_values
        ) VALUES (
            'membership_notifications',
            v_membership.membership_id,
            'NOTIFICATION',
            CURRENT_TIMESTAMP,
            jsonb_build_object(
                'email', v_membership.email,
                'message', v_notification_text,
                'renewal_status', COALESCE(v_payment_status, 'PENDING'),
                'new_membership_id', v_new_membership_id
            )
        );
    END LOOP;

    DROP TABLE membership_renewals;
END;
$$;
