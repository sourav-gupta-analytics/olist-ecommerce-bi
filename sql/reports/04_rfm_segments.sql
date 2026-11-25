WITH customer_history AS (
    SELECT
        o.customer_unique_id,
        CAST(JULIANDAY(DATE(b.last_purchased_at)) - JULIANDAY(DATE(MAX(o.purchased_at))) AS INTEGER)
            AS recency_days,
        COUNT(*) AS frequency,
        SUM(i.merchandise_cents) AS monetary_cents,
        COUNT(*) - COUNT(i.order_id) AS orders_without_items
    FROM delivered_customer_orders AS o
    CROSS JOIN study_observation AS b
    LEFT JOIN order_item_totals AS i USING (order_id)
    GROUP BY o.customer_unique_id, b.last_purchased_at
    HAVING COUNT(i.order_id) > 0
),
customer_percentiles AS (
    SELECT
        *,
        PERCENT_RANK() OVER (ORDER BY recency_days DESC) AS recency_percentile,
        PERCENT_RANK() OVER (ORDER BY monetary_cents) AS monetary_percentile,
        MIN(recency_days) OVER () = MAX(recency_days) OVER () AS recency_all_equal,
        MIN(monetary_cents) OVER () = MAX(monetary_cents) OVER () AS monetary_all_equal
    FROM customer_history
),
scores AS (
    SELECT
        *,
        CASE WHEN recency_all_equal THEN 3
            ELSE MIN(5, 1 + CAST(5 * recency_percentile AS INTEGER)) END AS recency_score,
        MIN(5, frequency) AS frequency_score,
        CASE WHEN monetary_all_equal THEN 3
            ELSE MIN(5, 1 + CAST(5 * monetary_percentile AS INTEGER)) END AS monetary_score
    FROM customer_percentiles
),
segments AS (
    SELECT
        *,
        CASE
            WHEN frequency_score >= 2 AND recency_score >= 4 AND monetary_score >= 4
                THEN 'High-value active repeat'
            WHEN frequency_score >= 2 AND recency_score <= 2 THEN 'At-risk repeat'
            WHEN frequency_score >= 2 THEN 'Other repeat'
            WHEN recency_score >= 4 THEN 'Recent one-time'
            WHEN recency_score <= 2 THEN 'Lapsed one-time'
            ELSE 'Other one-time'
        END AS segment
    FROM scores
),
summary AS (
    SELECT
        segment,
        COUNT(*) AS customers,
        COUNT(*) FILTER (WHERE orders_without_items > 0) AS customers_with_missing_item_orders,
        AVG(recency_days) AS average_recency_days,
        AVG(frequency) AS average_order_frequency,
        AVG(monetary_cents) AS average_monetary_cents,
        SUM(monetary_cents) AS monetary_cents
    FROM segments
    GROUP BY segment
)
SELECT
    segment,
    customers,
    ROUND(100.0 * customers / SUM(customers) OVER (), 2) AS customer_share_pct,
    customers_with_missing_item_orders,
    ROUND(average_recency_days, 1) AS average_recency_days,
    ROUND(average_order_frequency, 2) AS average_order_frequency,
    ROUND(average_monetary_cents / 100.0, 2) AS average_merchandise_sales_per_customer_brl,
    monetary_cents / 100.0 AS merchandise_sales_brl,
    ROUND(100.0 * monetary_cents / NULLIF(SUM(monetary_cents) OVER (), 0), 2) AS revenue_share_pct
FROM summary
ORDER BY monetary_cents DESC, segment;
