USE supply_chain_analytics;
SHOW TABLES;
SELECT COUNT(*) AS total_inventory_records
FROM inventory_raw;
SELECT COUNT(*) AS total_rows
FROM inventory_raw;
DESCRIBE inventory_raw;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT inventory_id) AS unique_inventory_ids
FROM inventory_raw;
SELECT inventory_id, COUNT(*) AS occurrences
FROM inventory_raw
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;
SELECT *
FROM inventory_raw
WHERE inventory_id = 'INV000160';
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT_WS('|',
        inventory_id,
        product_id,
        warehouse_id,
        date,
        stock_on_hand,
        reorder_point,
        safety_stock
    )) AS unique_complete_rows
FROM inventory_raw;
CREATE TABLE inventory_clean AS
SELECT DISTINCT *
FROM inventory_raw;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT inventory_id) AS unique_inventory_ids
FROM inventory_clean;
SELECT
    SUM(inventory_id IS NULL OR TRIM(inventory_id) = '') AS missing_inventory_ids,
    SUM(product_id IS NULL OR TRIM(product_id) = '') AS missing_product_ids,
    SUM(warehouse_id IS NULL OR TRIM(warehouse_id) = '') AS missing_warehouse_ids,
    SUM(`date` IS NULL OR TRIM(`date`) = '') AS missing_dates,
    SUM(stock_on_hand IS NULL) AS missing_stock,
    SUM(reorder_point IS NULL) AS missing_reorder_points,
    SUM(safety_stock IS NULL) AS missing_safety_stock
FROM inventory_clean;
SELECT inventory_id, `date`
FROM inventory_clean
WHERE `date` NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
LIMIT 15;
SELECT
    COUNT(*) AS total_rows,
    SUM(`date` REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$') AS hyphen_dates,
    SUM(`date` REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$') AS text_dates,
    SUM(`date` REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS iso_dates
FROM inventory_clean;
UPDATE inventory_clean
SET `date` = CASE
    WHEN `date` REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
        THEN DATE_FORMAT(
            STR_TO_DATE(`date`, '%d-%m-%Y'),
            '%Y-%m-%d'
        )
    WHEN `date` REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$'
        THEN DATE_FORMAT(
            STR_TO_DATE(`date`, '%b %d, %Y'),
            '%Y-%m-%d'
        )
    ELSE `date`
END
WHERE inventory_id IS NOT NULL;
SELECT
    COUNT(*) AS total_rows,
    SUM(`date` REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS standardized_dates,
    SUM(`date` NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS dates_needing_review
FROM inventory_clean;
SELECT *
FROM inventory_clean
WHERE stock_on_hand < 0
   OR reorder_point < 0
   OR safety_stock < 0;
   SELECT
    SUM(stock_on_hand < 0) AS negative_stock_records,
    SUM(reorder_point < 0) AS negative_reorder_points,
    SUM(safety_stock < 0) AS negative_safety_stock
FROM inventory_clean;
ALTER TABLE inventory_clean
ADD COLUMN stock_quality_flag VARCHAR(40) DEFAULT 'Valid';
UPDATE inventory_clean
SET stock_quality_flag = 'Review Negative Stock'
WHERE stock_on_hand < 0;
SELECT inventory_id, product_id, stock_on_hand, stock_quality_flag
FROM inventory_clean
WHERE stock_quality_flag = 'Review Negative Stock'
LIMIT 10;
SELECT COUNT(*) AS below_reorder_point
FROM inventory_clean
WHERE stock_on_hand >= 0
  AND stock_on_hand < reorder_point;
  ALTER TABLE inventory_clean
ADD COLUMN reorder_status VARCHAR(30) DEFAULT 'Stock Sufficient';
UPDATE inventory_clean
SET reorder_status = 'Below Reorder Point'
WHERE stock_on_hand >= 0
  AND stock_on_hand < reorder_point;
  SELECT reorder_status, COUNT(*) AS record_count
FROM inventory_clean
GROUP BY reorder_status;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT inventory_id) AS unique_inventory_ids,
    SUM(`date` REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS standardized_dates,
    SUM(stock_quality_flag = 'Review Negative Stock') AS negative_stock_flags,
    SUM(reorder_status = 'Below Reorder Point') AS below_reorder_count
FROM inventory_clean;

