WITH category_orders AS (
    SELECT
        COALESCE(t.category_english, p.category, 'Uncategorized') AS category,
        i.order_id,
        COUNT(*) AS items_sold,
        SUM(i.price_cents) AS sales_cents
    FROM study_delivered_orders AS o
    JOIN order_items AS i USING (order_id)
    JOIN products AS p USING (product_id)
    LEFT JOIN category_translation AS t USING (category)
    GROUP BY COALESCE(t.category_english, p.category, 'Uncategorized'), i.order_id
),
category_volumes AS (
    SELECT category, COUNT(*) AS distinct_delivered_orders
    FROM category_orders
    GROUP BY category
),
combined_orders AS (
    SELECT
        CASE WHEN v.distinct_delivered_orders >= 20 THEN o.category END AS visible_category,
        o.order_id,
        SUM(o.items_sold) AS items_sold,
        SUM(o.sales_cents) AS sales_cents
    FROM category_orders AS o
    JOIN category_volumes AS v USING (category)
    GROUP BY visible_category, o.order_id
),
category_sales AS (
    SELECT
        visible_category,
        COUNT(*) AS distinct_delivered_orders,
        SUM(items_sold) AS items_sold,
        SUM(sales_cents) AS sales_cents,
        SUM(SUM(sales_cents)) OVER () AS all_sales_cents
    FROM combined_orders
    GROUP BY visible_category
)
SELECT
    COALESCE(visible_category, 'Other low-volume categories') AS category,
    DENSE_RANK() OVER (ORDER BY sales_cents DESC) AS category_rank,
    distinct_delivered_orders,
    items_sold,
    sales_cents / 100.0 AS merchandise_sales_brl,
    ROUND(100.0 * sales_cents / NULLIF(all_sales_cents, 0), 2) AS revenue_share_pct
FROM category_sales
WHERE distinct_delivered_orders >= 20
ORDER BY category_rank, category;
