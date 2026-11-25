WITH seller_order_totals AS (
    SELECT
        i.seller_id,
        i.order_id,
        COUNT(*) AS items_sold,
        SUM(i.price_cents) AS merchandise_cents
    FROM study_delivered_orders AS o
    JOIN order_items AS i USING (order_id)
    GROUP BY i.seller_id, i.order_id
),
seller_totals AS (
    SELECT
        seller_id,
        COUNT(*) AS delivered_order_count,
        SUM(items_sold) AS items_sold,
        SUM(merchandise_cents) AS merchandise_cents
    FROM seller_order_totals
    GROUP BY seller_id
),
tiered_sellers AS (
    SELECT
        delivered_order_count,
        items_sold,
        merchandise_cents,
        CASE
            WHEN delivered_order_count < 5 THEN 1
            WHEN delivered_order_count < 25 THEN 5
            WHEN delivered_order_count < 100 THEN 25
            ELSE 100
        END AS minimum_order_count
    FROM seller_totals
),
tier_totals AS (
    SELECT
        minimum_order_count,
        COUNT(*) AS seller_count,
        SUM(delivered_order_count) AS delivered_seller_order_pairs,
        SUM(items_sold) AS items_sold,
        SUM(merchandise_cents) AS merchandise_cents,
        SUM(SUM(merchandise_cents)) OVER () AS all_seller_merchandise_cents
    FROM tiered_sellers
    GROUP BY minimum_order_count
)
SELECT
    CASE minimum_order_count
        WHEN 1 THEN '1-4 delivered orders'
        WHEN 5 THEN '5-24 delivered orders'
        WHEN 25 THEN '25-99 delivered orders'
        ELSE '100+ delivered orders'
    END AS seller_order_volume_tier,
    seller_count,
    delivered_seller_order_pairs,
    items_sold,
    merchandise_cents / 100.0 AS merchandise_sales_brl,
    ROUND(100.0 * merchandise_cents / NULLIF(all_seller_merchandise_cents, 0), 2)
        AS merchandise_sales_share_pct
FROM tier_totals
WHERE seller_count >= 20
ORDER BY minimum_order_count;
