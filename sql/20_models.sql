-- Each of these child tables has one row per order before they are joined.
CREATE VIEW order_item_totals AS
SELECT
    order_id,
    COUNT(*) AS item_count,
    SUM(price_cents) AS merchandise_cents,
    SUM(freight_cents) AS freight_cents
FROM order_items
GROUP BY order_id;

CREATE VIEW order_payment_totals AS
SELECT
    order_id,
    COUNT(*) AS payment_count,
    SUM(payment_cents) AS paid_cents
FROM payments
GROUP BY order_id;

-- Join independent one-to-many relationships at order grain.
CREATE VIEW order_fact AS
SELECT
    o.order_id,
    c.customer_unique_id,
    c.state,
    o.status,
    o.purchased_at,
    o.delivered_at,
    o.estimated_delivery_date,
    COALESCE(i.item_count, 0) AS item_count,
    i.merchandise_cents,
    i.freight_cents,
    COALESCE(p.payment_count, 0) AS payment_count,
    p.paid_cents
FROM orders AS o
JOIN customers AS c USING (customer_id)
LEFT JOIN order_item_totals AS i USING (order_id)
LEFT JOIN order_payment_totals AS p USING (order_id);

CREATE VIEW study_delivered_orders AS
SELECT o.*
FROM orders AS o
CROSS JOIN analysis_settings AS s
WHERE o.status = 'delivered'
  AND (s.last_complete_month IS NULL OR o.purchased_at < DATE(s.last_complete_month, '+1 month'));

-- Reports that only need purchase events skip the item and payment aggregates.
CREATE VIEW delivered_customer_orders AS
SELECT o.order_id, c.customer_unique_id, c.state, o.purchased_at,
       o.delivered_at, o.estimated_delivery_date
FROM study_delivered_orders AS o
JOIN customers AS c USING (customer_id);

CREATE VIEW purchase_observation AS
SELECT MIN(purchased_at) AS first_purchased_at, MAX(purchased_at) AS last_purchased_at
FROM orders;

CREATE VIEW study_observation AS
SELECT
    p.first_purchased_at,
    CASE WHEN p.last_purchased_at >= DATE(s.last_complete_month, '+1 month')
        THEN DATETIME(s.last_complete_month, '+1 month', '-1 second')
        ELSE p.last_purchased_at
    END AS last_purchased_at
FROM purchase_observation AS p
CROSS JOIN analysis_settings AS s;

-- A boundary month is complete when the observed dates reach both month edges.
CREATE VIEW purchase_months AS
WITH RECURSIVE
bounds AS (
    SELECT DATE(first_purchased_at) AS first_day, DATE(last_purchased_at) AS last_day
    FROM purchase_observation
),
calendar(month_start) AS (
    SELECT DATE(first_day, 'start of month') FROM bounds WHERE first_day IS NOT NULL
    UNION ALL
    SELECT DATE(month_start, '+1 month')
    FROM calendar CROSS JOIN bounds
    WHERE month_start < DATE(last_day, 'start of month')
)
SELECT
    month_start,
    CASE
        WHEN month_start < s.first_complete_month OR month_start > s.last_complete_month
        THEN 'outside_study_window'
        WHEN month_start < first_day OR DATE(month_start, '+1 month', '-1 day') > last_day
        THEN 'partial'
        ELSE 'complete'
    END AS month_coverage
FROM calendar CROSS JOIN bounds CROSS JOIN analysis_settings AS s;
