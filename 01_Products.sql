USE supply_chain_analytics;
SHOW TABLES;
SELECT * 
FROM products_raw
LIMIT 10;
SELECT COUNT(*) AS total_products
FROM products_raw;
SELECT COUNT(*) AS total_clean_products
FROM products_clean;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_product_ids
FROM products_clean;
SELECT product_id, unit_cost, unit_price
FROM products_clean
WHERE unit_cost < 0
   OR unit_price < 0;
   DESCRIBE products_clean;
   UPDATE products_clean
SET cost_quality_flag = 'Review Negative Cost'
WHERE unit_cost < 0;
SELECT product_id, unit_cost, cost_quality_flag
FROM products_clean
WHERE cost_quality_flag = 'Review Negative Cost';
SELECT
    SUM(product_id IS NULL) AS missing_product_ids,
    SUM(product_name IS NULL) AS missing_product_names,
    SUM(category IS NULL) AS missing_categories,
    SUM(sub_category IS NULL) AS missing_sub_categories,
    SUM(unit_cost IS NULL) AS missing_unit_costs,
    SUM(unit_price IS NULL) AS missing_unit_prices,
    SUM(supplier_id IS NULL) AS missing_supplier_ids
FROM products_clean;
SELECT
    COUNT(*) AS blank_text_records
FROM products_clean
WHERE TRIM(product_id) = ''
   OR TRIM(product_name) = ''
   OR TRIM(category) = ''
   OR TRIM(sub_category) = ''
   OR TRIM(supplier_id) = '';
   SELECT *
FROM products_clean
WHERE TRIM(product_id) = ''
   OR TRIM(product_name) = ''
   OR TRIM(category) = ''
   OR TRIM(sub_category) = ''
   OR TRIM(supplier_id) = '';
   UPDATE products_clean
SET cost_quality_flag = 'Review Supplier ID'
WHERE supplier_id IS NULL
   OR TRIM(supplier_id) = '';
   SELECT product_id, supplier_id, cost_quality_flag
FROM products_clean
WHERE cost_quality_flag = 'Review Supplier ID';
SELECT DISTINCT category
FROM products_clean
ORDER BY category;
UPDATE products_clean
SET category = CASE
    WHEN LOWER(TRIM(category)) = 'apparel' THEN 'Apparel'
    WHEN LOWER(TRIM(category)) = 'electronics' THEN 'Electronics'
    WHEN LOWER(TRIM(category)) = 'grocery' THEN 'Grocery'
    WHEN LOWER(TRIM(category)) = 'home & kitchen' THEN 'Home & Kitchen'
    WHEN LOWER(TRIM(category)) = 'personal care' THEN 'Personal Care'
    ELSE TRIM(category)
END;
SELECT DISTINCT category
FROM products_clean
ORDER BY category;
SELECT DISTINCT sub_category
FROM products_clean
ORDER BY sub_category;
UPDATE products_clean
SET sub_category = CONCAT(
    UPPER(LEFT(TRIM(sub_category), 1)),
    LOWER(SUBSTRING(TRIM(sub_category), 2))
);
SELECT DISTINCT sub_category
FROM products_clean
ORDER BY sub_category;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_product_ids,
    SUM(cost_quality_flag = 'Review Negative Cost') AS negative_cost_flags,
    SUM(cost_quality_flag = 'Review Supplier ID') AS missing_supplier_flags
FROM products_clean;
