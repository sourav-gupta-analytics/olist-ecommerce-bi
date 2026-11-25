-- All three cost rates are illustrative assumptions on delivered merchandise sales.
WITH scenarios(scenario, assumed_cogs_pct, assumed_processing_pct, assumed_fulfillment_pct) AS (
    VALUES ('Low cost', 55, 3, 5), ('Base case', 65, 3, 5), ('High cost', 75, 3, 5)
),
sales AS (
    SELECT
        COUNT(*) FILTER (WHERE i.item_count > 0) AS delivered_orders_with_items,
        SUM(i.merchandise_cents) AS merchandise_cents
    FROM study_delivered_orders AS o
    LEFT JOIN order_item_totals AS i USING (order_id)
)
SELECT
    scenario,
    delivered_orders_with_items,
    merchandise_cents / 100.0 AS merchandise_sales_brl,
    assumed_cogs_pct,
    assumed_processing_pct,
    assumed_fulfillment_pct,
    100 - assumed_cogs_pct - assumed_processing_pct - assumed_fulfillment_pct AS scenario_contribution_margin_pct,
    ROUND(merchandise_cents * (100.0 - assumed_cogs_pct - assumed_processing_pct - assumed_fulfillment_pct)
          / 10000, 2) AS scenario_contribution_brl
FROM scenarios CROSS JOIN sales
ORDER BY assumed_cogs_pct;
