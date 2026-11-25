WITH order_amounts AS (
    SELECT
        CASE WHEN status = 'delivered' THEN 'delivered' ELSE 'other_statuses' END AS status_group,
        item_count,
        payment_count,
        CASE WHEN item_count > 0 AND payment_count > 0
            THEN merchandise_cents + freight_cents
        END AS expected_cents,
        CASE WHEN item_count > 0 AND payment_count > 0 THEN paid_cents END AS comparable_paid_cents
    FROM order_fact
),
reconciled AS (
    SELECT *, comparable_paid_cents - expected_cents AS delta_cents
    FROM order_amounts
),
report_groups(order_status, is_overall) AS (
    VALUES ('all_statuses', 1), ('delivered', 0), ('other_statuses', 0)
)
SELECT
    g.order_status,
    COUNT(r.status_group) AS order_count,
    COUNT(r.delta_cents) AS comparable_orders,
    COUNT(*) FILTER (WHERE ABS(r.delta_cents) <= 1) AS matched_orders,
    COUNT(*) FILTER (WHERE ABS(r.delta_cents) > 1) AS mismatched_orders,
    COUNT(*) FILTER (WHERE r.item_count = 0) AS missing_item_orders,
    COUNT(*) FILTER (WHERE r.payment_count = 0) AS missing_payment_orders,
    SUM(r.expected_cents) / 100.0 AS comparable_item_plus_freight_brl,
    SUM(r.comparable_paid_cents) / 100.0 AS comparable_paid_brl,
    SUM(r.delta_cents) / 100.0 AS net_payment_delta_brl,
    SUM(ABS(r.delta_cents)) / 100.0 AS absolute_payment_delta_brl
FROM report_groups AS g
LEFT JOIN reconciled AS r ON g.is_overall = 1 OR r.status_group = g.order_status
GROUP BY g.is_overall, g.order_status
ORDER BY g.is_overall DESC, g.order_status;
