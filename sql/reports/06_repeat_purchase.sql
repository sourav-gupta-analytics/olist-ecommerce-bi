WITH chronological_purchases AS (
    SELECT
        customer_unique_id,
        purchased_at,
        ROW_NUMBER() OVER purchase_sequence AS purchase_number,
        LEAD(purchased_at) OVER purchase_sequence AS next_purchased_at
    FROM delivered_customer_orders
    WINDOW purchase_sequence AS (PARTITION BY customer_unique_id ORDER BY purchased_at, order_id)
),
first_purchases AS (
    SELECT
        p.next_purchased_at IS NOT NULL AS repeated,
        JULIANDAY(p.purchased_at) + 90 <= JULIANDAY(o.last_purchased_at) AS eligible_at_90d,
        JULIANDAY(p.next_purchased_at) <= JULIANDAY(p.purchased_at) + 90 AS repeated_by_90d
    FROM chronological_purchases AS p
    CROSS JOIN study_observation AS o
    WHERE p.purchase_number = 1
),
totals AS (
    SELECT
        COUNT(*) AS delivered_customers,
        COUNT(*) FILTER (WHERE repeated) AS repeat_customers,
        COUNT(*) FILTER (WHERE eligible_at_90d) AS eligible_customers_90d,
        COUNT(*) FILTER (WHERE eligible_at_90d AND repeated_by_90d) AS repeat_customers_within_90d
    FROM first_purchases
)
SELECT
    delivered_customers,
    repeat_customers,
    ROUND(100.0 * repeat_customers / NULLIF(delivered_customers, 0), 2) AS observed_repeat_customer_pct,
    eligible_customers_90d,
    repeat_customers_within_90d,
    ROUND(100.0 * repeat_customers_within_90d / NULLIF(eligible_customers_90d, 0), 2)
        AS eligible_repeat_customer_pct_90d
FROM totals;
