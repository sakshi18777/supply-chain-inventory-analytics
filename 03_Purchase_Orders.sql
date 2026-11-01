-- Supply Chain Analytics: essential cleaning workflow
-- Assumes products_raw and purchase_orders_raw are already imported.
-- Run this script only after confirming those two raw tables exist.

USE supply_chain_analytics;


-- 1. Rebuild the cleaned products table
DROP TABLE IF EXISTS products_clean;

CREATE TABLE products_clean AS
SELECT DISTINCT *
FROM products_raw
WHERE product_id IS NOT NULL
  AND TRIM(product_id) <> '';

ALTER TABLE products_clean
ADD COLUMN cost_quality_flag VARCHAR(30) DEFAULT 'Valid';

UPDATE products_clean
SET cost_quality_flag = CASE
    WHEN unit_cost IS NULL THEN 'Missing Cost'
    WHEN unit_cost < 0 THEN 'Review Negative Cost'
    ELSE 'Valid'
END;

-- Product QA: totals and flagged costs
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(unit_cost IS NULL) AS missing_costs,
    SUM(unit_cost < 0) AS negative_costs
FROM products_clean;

SELECT product_id, unit_cost, cost_quality_flag
FROM products_clean
WHERE cost_quality_flag <> 'Valid'
ORDER BY product_id;

-- 2. Rebuild the cleaned purchase orders table
DROP TABLE IF EXISTS purchase_orders_clean;

CREATE TABLE purchase_orders_clean AS
SELECT DISTINCT *
FROM purchase_orders_raw;

ALTER TABLE purchase_orders_clean
ADD COLUMN delivery_date_quality_flag VARCHAR(40) DEFAULT 'Valid';

UPDATE purchase_orders_clean
SET delivery_date_quality_flag = CASE
    WHEN actual_delivery_date IS NULL
      OR TRIM(actual_delivery_date) = ''
    THEN 'Missing Actual Date'
    ELSE 'Valid'
END;

-- Standardize order_date to YYYY-MM-DD.
-- Slash-formatted dates are interpreted as MM/DD/YYYY, matching the earlier checks.
UPDATE purchase_orders_clean
SET order_date = CASE
    WHEN order_date LIKE '%/%'
      THEN DATE_FORMAT(STR_TO_DATE(order_date, '%m/%d/%Y'), '%Y-%m-%d')
    WHEN order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
      THEN DATE_FORMAT(STR_TO_DATE(order_date, '%d-%m-%Y'), '%Y-%m-%d')
    ELSE order_date
END;

-- Purchase-order QA
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT po_id) AS unique_po_ids,
    SUM(po_id IS NULL OR TRIM(po_id) = '') AS missing_po_ids,
    SUM(actual_delivery_date IS NULL OR TRIM(actual_delivery_date) = '') AS missing_actual_dates,
    SUM(quantity_ordered IS NULL) AS missing_ordered_qty,
    SUM(quantity_received IS NULL) AS missing_received_qty
FROM purchase_orders_clean;

SELECT delivery_date_quality_flag, COUNT(*) AS total_records
FROM purchase_orders_clean
GROUP BY delivery_date_quality_flag;

SELECT po_id, COUNT(*) AS record_count
FROM purchase_orders_clean
GROUP BY po_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC, po_id;

SELECT po_id, order_date
FROM purchase_orders_clean
WHERE order_date IS NULL
   OR order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
ORDER BY po_id;

SELECT *
FROM purchase_orders_clean
LIMIT 100;

SELECT COUNT(*) AS total_records
FROM purchase_orders_clean;
