WITH customer_month_activity AS (
    SELECT DISTINCT customer_unique_id, DATE(purchased_at, 'start of month') AS activity_month
    FROM delivered_customer_orders
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(activity_month) AS cohort_month
    FROM customer_month_activity
    GROUP BY customer_unique_id
),
complete_months AS (
    SELECT month_start FROM purchase_months WHERE month_coverage = 'complete'
),
cohort_sizes AS (
    SELECT c.cohort_month, COUNT(*) AS cohort_customers
    FROM customer_cohorts AS c
    JOIN complete_months AS m ON m.month_start = c.cohort_month
    GROUP BY c.cohort_month
),
active_by_cohort_month AS (
    SELECT c.cohort_month, a.activity_month, COUNT(*) AS active_customers
    FROM customer_cohorts AS c
    JOIN customer_month_activity AS a USING (customer_unique_id)
    JOIN cohort_sizes AS s USING (cohort_month)
    GROUP BY c.cohort_month, a.activity_month
)
SELECT
    s.cohort_month,
    m.month_start AS activity_month,
    12 * (CAST(STRFTIME('%Y', m.month_start) AS INTEGER) - CAST(STRFTIME('%Y', s.cohort_month) AS INTEGER))
        + CAST(STRFTIME('%m', m.month_start) AS INTEGER)
        - CAST(STRFTIME('%m', s.cohort_month) AS INTEGER) AS months_since_first_purchase,
    s.cohort_customers,
    COALESCE(a.active_customers, 0) AS active_customers,
    ROUND(100.0 * COALESCE(a.active_customers, 0) / s.cohort_customers, 2) AS retention_pct
FROM cohort_sizes AS s
JOIN complete_months AS m ON m.month_start >= s.cohort_month
LEFT JOIN active_by_cohort_month AS a ON a.cohort_month = s.cohort_month AND a.activity_month = m.month_start
ORDER BY s.cohort_month, m.month_start;
