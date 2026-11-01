use SalesData
select * from dbo.inventory
select * from dbo.products
select * from dbo.warehouses
select * from dbo.purchase_orders
select * from dbo.returns
select * from dbo.sales_orders
select * from dbo.suppliers

/* =========================================================
   SUPPLY CHAIN & INVENTORY ANALYTICS - SQL ANALYSIS QUERIES
   Database: SalesData (SQL Server / SSMS)
   ========================================================= */


/* ---------------------------------------------------------
   1. STOCKOUT FREQUENCY
   Q: Which products/warehouses run out of stock most often,
      and how frequently?
   --------------------------------------------------------- */
SELECT
    i.product_id,
    p.product_name,
    i.warehouse_id,
    w.warehouse_name,
    COUNT(*) AS stockout_weeks
FROM inventory i
JOIN products p   ON p.product_id = i.product_id
JOIN warehouses w ON w.warehouse_id = i.warehouse_id
WHERE i.stock_on_hand = 0
GROUP BY i.product_id, p.product_name, i.warehouse_id, w.warehouse_name
ORDER BY stockout_weeks DESC;


/* ---------------------------------------------------------
   2. REORDER POINT BREACHES
   Q: How often does stock fall below the reorder point
      before restocking - are we reordering late?
   --------------------------------------------------------- */
SELECT
    warehouse_id,
    COUNT(*) AS total_snapshots,
    SUM(CASE WHEN stock_on_hand < reorder_point THEN 1 ELSE 0 END) AS breach_count,
    CAST(
        SUM(CASE WHEN stock_on_hand < reorder_point THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)
    ) AS breach_pct
FROM inventory
GROUP BY warehouse_id
ORDER BY breach_pct DESC;


/* ---------------------------------------------------------
   3. INVENTORY TURNOVER RATIO
   Q: Which products/categories sell fast relative to how
      much stock we hold (over- or under-stocked)?
   --------------------------------------------------------- */
WITH avg_stock AS (
    SELECT product_id, AVG(CAST(stock_on_hand AS FLOAT)) AS avg_stock_on_hand
    FROM inventory
    GROUP BY product_id
),
units_sold AS (
    SELECT product_id, SUM(quantity) AS total_units_sold
    FROM sales_orders
    WHERE status = 'Delivered'
    GROUP BY product_id
)
SELECT
    p.product_id,
    p.product_name,
    p.category,
    ISNULL(u.total_units_sold, 0) AS units_sold,
    ROUND(a.avg_stock_on_hand, 1) AS avg_stock_on_hand,
    ROUND(ISNULL(u.total_units_sold, 0) / NULLIF(a.avg_stock_on_hand, 0), 2) AS turnover_ratio
FROM products p
JOIN avg_stock a  ON a.product_id = p.product_id
LEFT JOIN units_sold u ON u.product_id = p.product_id
ORDER BY turnover_ratio DESC;


/* ---------------------------------------------------------
   4. ABC PRODUCT CLASSIFICATION
   Q: Which products drive the majority of revenue vs.
      which are low-value/slow movers?
   --------------------------------------------------------- */
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(so.quantity * p.unit_price) AS revenue
    FROM sales_orders so
    JOIN products p ON p.product_id = so.product_id
    WHERE so.status = 'Delivered'
    GROUP BY p.product_id, p.product_name, p.category
),
ranked AS (
    SELECT
        *,
        SUM(revenue) OVER () AS total_revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
    FROM product_revenue
)
SELECT
    product_id,
    product_name,
    category,
    revenue,
    ROUND(running_revenue * 100.0 / total_revenue, 2) AS cumulative_pct,
    CASE
        WHEN running_revenue * 100.0 / total_revenue <= 70 THEN 'A'
        WHEN running_revenue * 100.0 / total_revenue <= 90 THEN 'B'
        ELSE 'C'
    END AS abc_tier
FROM ranked
ORDER BY revenue DESC;


/* ---------------------------------------------------------
   5. SUPPLIER DELIVERY DELAY
   Q: Which suppliers consistently deliver late, and by
      how many days on average?
   --------------------------------------------------------- */
SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(po.po_id) AS total_orders,
    AVG(DATEDIFF(DAY, po.expected_delivery_date, po.actual_delivery_date)) AS avg_delay_days,
    MAX(DATEDIFF(DAY, po.expected_delivery_date, po.actual_delivery_date)) AS max_delay_days
FROM purchase_orders po
JOIN suppliers s ON s.supplier_id = po.supplier_id
WHERE po.actual_delivery_date IS NOT NULL
GROUP BY s.supplier_id, s.supplier_name
ORDER BY avg_delay_days DESC;


/* ---------------------------------------------------------
   6. SUPPLIER RISK SCORE
   Q: Which suppliers are highest-risk to depend on
      (delay + reliability combined)?
   --------------------------------------------------------- */
WITH delay_stats AS (
    SELECT
        supplier_id,
        AVG(DATEDIFF(DAY, expected_delivery_date, actual_delivery_date)) AS avg_delay_days
    FROM purchase_orders
    WHERE actual_delivery_date IS NOT NULL
    GROUP BY supplier_id
)
SELECT
    s.supplier_id,
    s.supplier_name,
    s.reliability_score,
    d.avg_delay_days,
    RANK() OVER (
        ORDER BY d.avg_delay_days DESC, s.reliability_score ASC
    ) AS risk_rank
FROM suppliers s
JOIN delay_stats d ON d.supplier_id = s.supplier_id
ORDER BY risk_rank;


/* ---------------------------------------------------------
   7. SUPPLIER FULFILLMENT ACCURACY
   Q: How often do suppliers under-deliver the quantity
      ordered (partial fulfillment)?
   --------------------------------------------------------- */
SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(*) AS total_pos,
    SUM(CASE WHEN po.quantity_received < po.quantity_ordered THEN 1 ELSE 0 END) AS partial_fulfillments,
    CAST(
        SUM(CASE WHEN po.quantity_received < po.quantity_ordered THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)
    ) AS partial_fulfillment_pct
FROM purchase_orders po
JOIN suppliers s ON s.supplier_id = po.supplier_id
WHERE po.quantity_received IS NOT NULL
GROUP BY s.supplier_id, s.supplier_name
ORDER BY partial_fulfillment_pct DESC;


/* ---------------------------------------------------------
   8. WAREHOUSE FULFILLMENT PERFORMANCE
   Q: Which warehouses are worst at on-time order fulfillment?
   --------------------------------------------------------- */
SELECT
    w.warehouse_id,
    w.warehouse_name,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN so.status IN ('Delayed','Cancelled') THEN 1 ELSE 0 END) AS problem_orders,
    CAST(
        SUM(CASE WHEN so.status IN ('Delayed','Cancelled') THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)
    ) AS problem_pct,
    RANK() OVER (ORDER BY
        SUM(CASE WHEN so.status IN ('Delayed','Cancelled') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) DESC
    ) AS worst_rank
FROM sales_orders so
JOIN warehouses w ON w.warehouse_id = so.warehouse_id
GROUP BY w.warehouse_id, w.warehouse_name
ORDER BY problem_pct DESC;


/* ---------------------------------------------------------
   9. STOCKOUT-TO-SALES RISK
   Q: Which warehouse-product combos have the highest
      stockout frequency relative to how much they sell
      (biggest lost-sales risk)?
   --------------------------------------------------------- */
WITH stockouts AS (
    SELECT product_id, warehouse_id, COUNT(*) AS stockout_weeks
    FROM inventory
    WHERE stock_on_hand = 0
    GROUP BY product_id, warehouse_id
),
sales AS (
    SELECT product_id, warehouse_id, SUM(quantity) AS units_sold
    FROM sales_orders
    WHERE status = 'Delivered'
    GROUP BY product_id, warehouse_id
)
SELECT
    p.product_name,
    w.warehouse_name,
    s.units_sold,
    st.stockout_weeks,
    ROUND(CAST(st.stockout_weeks AS FLOAT) / NULLIF(s.units_sold, 0), 4) AS stockout_to_sales_ratio
FROM stockouts st
JOIN sales s ON s.product_id = st.product_id AND s.warehouse_id = st.warehouse_id
JOIN products p ON p.product_id = st.product_id
JOIN warehouses w ON w.warehouse_id = st.warehouse_id
ORDER BY stockout_to_sales_ratio DESC;


/* ---------------------------------------------------------
   10. MONTHLY DEMAND TREND (ROLLING AVERAGE)
   Q: Is demand trending up/down or seasonal by category,
      month over month?
   --------------------------------------------------------- */
WITH monthly_sales AS (
    SELECT
        p.category,
        DATEFROMPARTS(YEAR(so.order_date), MONTH(so.order_date), 1) AS sales_month,
        SUM(so.quantity) AS units_sold
    FROM sales_orders so
    JOIN products p ON p.product_id = so.product_id
    WHERE so.status = 'Delivered'
    GROUP BY p.category, DATEFROMPARTS(YEAR(so.order_date), MONTH(so.order_date), 1)
)
SELECT
    category,
    sales_month,
    units_sold,
    ROUND(AVG(CAST(units_sold AS FLOAT)) OVER (
        PARTITION BY category
        ORDER BY sales_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1) AS rolling_3mo_avg
FROM monthly_sales
ORDER BY category, sales_month;


/* ---------------------------------------------------------
   11. TOP PRODUCTS PER CATEGORY
   Q: Within each category, which specific products are
      the top revenue contributors?
   --------------------------------------------------------- */
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        SUM(so.quantity * p.unit_price) AS revenue
    FROM sales_orders so
    JOIN products p ON p.product_id = so.product_id
    WHERE so.status = 'Delivered'
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT
        category,
        product_name,
        revenue,
        RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT *
FROM ranked
WHERE rank_in_category <= 5
ORDER BY category, rank_in_category;


/* ---------------------------------------------------------
   12. MONTH-OVER-MONTH REVENUE GROWTH BY CATEGORY
   Q: What's the month-over-month revenue growth rate
      by category?
   --------------------------------------------------------- */
WITH monthly_revenue AS (
    SELECT
        p.category,
        DATEFROMPARTS(YEAR(so.order_date), MONTH(so.order_date), 1) AS revenue_month,
        SUM(so.quantity * p.unit_price) AS revenue
    FROM sales_orders so
    JOIN products p ON p.product_id = so.product_id
    WHERE so.status = 'Delivered'
    GROUP BY p.category, DATEFROMPARTS(YEAR(so.order_date), MONTH(so.order_date), 1)
)
SELECT
    category,
    revenue_month,
    revenue,
    LAG(revenue) OVER (PARTITION BY category ORDER BY revenue_month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY category ORDER BY revenue_month)) * 100.0
        / NULLIF(LAG(revenue) OVER (PARTITION BY category ORDER BY revenue_month), 0),
        2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY category, revenue_month;


/* ---------------------------------------------------------
   13. RETURN RATE BY CATEGORY / REASON
   Q: What % of orders get returned, and is it concentrated
      in specific categories or reasons?
   --------------------------------------------------------- */
SELECT
    p.category,
    r.reason,
    COUNT(*) AS return_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY p.category),
        2
    ) AS pct_of_category_returns
FROM returns r
JOIN products p ON p.product_id = r.product_id
GROUP BY p.category, r.reason
ORDER BY p.category, return_count DESC;