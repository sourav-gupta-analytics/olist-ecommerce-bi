WITH monthly AS (
    SELECT
        DATE(o.purchased_at, 'start of month') AS month_start,
        COUNT(*) AS order_count,
        COUNT(*) FILTER (WHERE o.status = 'delivered') AS delivered_order_count,
        COUNT(i.order_id) FILTER (WHERE o.status = 'delivered') AS delivered_orders_with_items,
        SUM(i.merchandise_cents) FILTER (WHERE o.status = 'delivered') AS merchandise_cents,
        SUM(i.freight_cents) FILTER (WHERE o.status = 'delivered') AS freight_cents
    FROM orders AS o
    LEFT JOIN order_item_totals AS i USING (order_id)
    GROUP BY DATE(o.purchased_at, 'start of month')
),
dense_monthly AS (
    SELECT
        c.month_start,
        c.month_coverage,
        COALESCE(m.order_count, 0) AS order_count,
        COALESCE(m.delivered_order_count, 0) AS delivered_order_count,
        COALESCE(m.delivered_orders_with_items, 0) AS delivered_orders_with_items,
        COALESCE(m.merchandise_cents, 0) AS merchandise_cents,
        COALESCE(m.freight_cents, 0) AS freight_cents
    FROM purchase_months AS c
    LEFT JOIN monthly AS m USING (month_start)
),
growth_baseline AS (
    SELECT
        *,
        LAG(merchandise_cents) OVER month_order AS previous_merchandise_cents,
        LAG(month_coverage) OVER month_order AS previous_month_coverage
    FROM dense_monthly
    WINDOW month_order AS (ORDER BY month_start)
)
SELECT
    month_start,
    month_coverage,
    order_count,
    delivered_order_count,
    delivered_orders_with_items,
    CASE WHEN month_coverage <> 'outside_study_window' THEN merchandise_cents / 100.0 END
        AS merchandise_sales_brl,
    CASE WHEN month_coverage <> 'outside_study_window' THEN freight_cents / 100.0 END
        AS freight_charged_brl,
    CASE WHEN month_coverage <> 'outside_study_window'
        THEN ROUND(merchandise_cents / (100.0 * NULLIF(delivered_orders_with_items, 0)), 2)
    END AS average_order_value_brl,
    CASE WHEN month_coverage = 'complete' AND previous_month_coverage = 'complete'
        THEN ROUND(100.0 * (merchandise_cents - previous_merchandise_cents)
                   / NULLIF(previous_merchandise_cents, 0), 2)
    END AS merchandise_sales_mom_pct
FROM growth_baseline
ORDER BY month_start;
