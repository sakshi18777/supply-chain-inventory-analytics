USE supply_chain_analytics;
SHOW TABLES;
SELECT COUNT(*) AS total_sales_orders
FROM sales_orders_raw;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM sales_orders_raw;
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM sales_orders_raw
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;
SELECT *
FROM sales_orders_raw
WHERE order_id = 'SO000080';
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT_WS('|',
        order_id, product_id, warehouse_id, customer_id,
        order_date, ship_date, delivery_date, quantity, status
    )) AS unique_complete_rows
FROM sales_orders_raw;
CREATE TABLE sales_orders_clean AS
SELECT DISTINCT *
FROM sales_orders_raw;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM sales_orders_clean;
SELECT order_id, order_date, ship_date, delivery_date
FROM sales_orders_clean
LIMIT 15;
DESCRIBE sales_orders_clean;
SELECT
    COUNT(*) AS total_rows,
    SUM(order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS order_iso_dates,
    SUM(ship_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS ship_iso_dates,
    SUM(delivery_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS delivery_iso_dates,
    SUM(order_date IS NULL OR TRIM(order_date) = '') AS missing_order_dates,
    SUM(ship_date IS NULL OR TRIM(ship_date) = '') AS missing_ship_dates,
    SUM(delivery_date IS NULL OR TRIM(delivery_date) = '') AS missing_delivery_dates
FROM sales_orders_clean;
SELECT order_id, order_date
FROM sales_orders_clean
WHERE order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
LIMIT 20;
SELECT
    SUM(order_date LIKE '%/%') AS slash_dates,
    SUM(order_date LIKE '%-%'
        AND order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
        AS hyphen_dates
FROM sales_orders_clean;
SELECT order_id, order_date
FROM sales_orders_clean
WHERE order_date LIKE '%-%'
  AND order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
LIMIT 15;
SET SQL_SAFE_UPDATES = 0;
UPDATE sales_orders_clean
SET order_date = CASE
    WHEN order_date LIKE '%/%'
        THEN DATE_FORMAT(
            STR_TO_DATE(order_date, '%m/%d/%Y'),
            '%Y-%m-%d'
        )
    WHEN order_date LIKE '%-%'
        AND order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN DATE_FORMAT(
            STR_TO_DATE(order_date, '%d-%m-%Y'),
            '%Y-%m-%d'
        )
    ELSE order_date
END
WHERE order_id IS NOT NULL;
SELECT
    COUNT(*) AS total_rows,
    SUM(order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS standardized_dates,
    SUM(order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        OR order_date IS NULL) AS dates_needing_review
FROM sales_orders_clean;
SELECT order_id, ship_date
FROM sales_orders_clean
WHERE ship_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
LIMIT 15;
UPDATE sales_orders_clean
SET ship_date = DATE_FORMAT(
    STR_TO_DATE(ship_date, '%d-%m-%Y'),
    '%Y-%m-%d'
)
WHERE ship_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$';
SELECT
    COUNT(*) AS total_rows,
    SUM(ship_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS standardized_dates,
    SUM(ship_date IS NULL OR TRIM(ship_date) = '') AS missing_ship_dates
FROM sales_orders_clean;
SELECT order_id, delivery_date
FROM sales_orders_clean
WHERE delivery_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND delivery_date IS NOT NULL
  AND TRIM(delivery_date) <> ''
LIMIT 15;
UPDATE sales_orders_clean
SET delivery_date = DATE_FORMAT(
    STR_TO_DATE(delivery_date, '%d/%m/%Y'),
    '%Y-%m-%d'
)
WHERE delivery_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';
SELECT
    COUNT(*) AS total_rows,
    SUM(delivery_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS standardized_dates,
    SUM(delivery_date IS NULL OR TRIM(delivery_date) = '') AS missing_delivery_dates
FROM sales_orders_clean;
SELECT DISTINCT status
FROM sales_orders_clean
ORDER BY status;
UPDATE sales_orders_clean
SET status = CASE
    WHEN LOWER(TRIM(status)) = 'delivered' THEN 'Delivered'
    WHEN LOWER(TRIM(status)) = 'delayed' THEN 'Delayed'
    WHEN LOWER(TRIM(status)) = 'cancelled' THEN 'Cancelled'
    ELSE TRIM(status)
END;
SELECT DISTINCT status
FROM sales_orders_clean
ORDER BY status;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    SUM(order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS invalid_order_dates,
    SUM(ship_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS invalid_ship_dates,
    SUM(delivery_date IS NULL OR TRIM(delivery_date) = '') AS missing_delivery_dates
FROM sales_orders_clean;
