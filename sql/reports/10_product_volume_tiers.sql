-- Olist records item lines without a separate quantity field.
WITH product_totals AS (
    SELECT
        i.product_id,
        COUNT(*) AS delivered_item_lines,
        SUM(i.price_cents) AS merchandise_cents
    FROM study_delivered_orders AS o
    JOIN order_items AS i USING (order_id)
    GROUP BY i.product_id
),
tiered_products AS (
    SELECT
        delivered_item_lines,
        merchandise_cents,
        CASE
            WHEN delivered_item_lines = 1 THEN 1
            WHEN delivered_item_lines < 5 THEN 2
            WHEN delivered_item_lines < 20 THEN 5
            WHEN delivered_item_lines < 100 THEN 20
            ELSE 100
        END AS minimum_line_count
    FROM product_totals
),
tier_totals AS (
    SELECT
        minimum_line_count,
        COUNT(*) AS product_count,
        SUM(delivered_item_lines) AS delivered_item_lines,
        SUM(merchandise_cents) AS merchandise_cents,
        SUM(SUM(merchandise_cents)) OVER () AS all_product_merchandise_cents
    FROM tiered_products
    GROUP BY minimum_line_count
)
SELECT
    CASE minimum_line_count
        WHEN 1 THEN '1 delivered line'
        WHEN 2 THEN '2-4 delivered lines'
        WHEN 5 THEN '5-19 delivered lines'
        WHEN 20 THEN '20-99 delivered lines'
        ELSE '100+ delivered lines'
    END AS product_volume_tier,
    product_count,
    delivered_item_lines,
    merchandise_cents / 100.0 AS merchandise_sales_brl,
    ROUND(100.0 * merchandise_cents / NULLIF(all_product_merchandise_cents, 0), 2)
        AS merchandise_sales_share_pct
FROM tier_totals
WHERE product_count >= 20
ORDER BY minimum_line_count;
