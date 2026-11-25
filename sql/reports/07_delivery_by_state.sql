WITH order_timings AS (
    SELECT
        state,
        CASE WHEN JULIANDAY(delivered_at) >= JULIANDAY(purchased_at)
            THEN JULIANDAY(delivered_at) - JULIANDAY(purchased_at)
        END AS delivery_days,
        CASE WHEN JULIANDAY(delivered_at) >= JULIANDAY(purchased_at)
            AND DATE(estimated_delivery_date) >= DATE(purchased_at)
            THEN DATE(delivered_at) <= DATE(estimated_delivery_date)
        END AS on_time
    FROM delivered_customer_orders
),
state_timings AS (
    SELECT
        state,
        COUNT(*) AS delivered_orders,
        COUNT(delivery_days) AS valid_duration_orders,
        COUNT(on_time) AS sla_eligible_orders,
        AVG(delivery_days) AS average_delivery_days,
        SUM(on_time) AS on_time_orders
    FROM order_timings
    GROUP BY state
    HAVING COUNT(*) >= 20
)
SELECT
    state,
    delivered_orders,
    valid_duration_orders,
    sla_eligible_orders,
    CASE WHEN sla_eligible_orders >= 20 THEN on_time_orders END AS on_time_orders,
    CASE WHEN sla_eligible_orders >= 20 THEN sla_eligible_orders - on_time_orders END AS late_orders,
    CASE WHEN sla_eligible_orders >= 20 THEN ROUND(100.0 * on_time_orders / sla_eligible_orders, 2) END
        AS on_time_delivery_pct,
    CASE WHEN valid_duration_orders >= 20 THEN ROUND(average_delivery_days, 2) END AS average_delivery_days
FROM state_timings
ORDER BY delivered_orders DESC, state;
