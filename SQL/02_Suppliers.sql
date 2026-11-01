
USE supply_chain_analytics;

SELECT COUNT(*) AS current_records
FROM suppliers_raw;

DESCRIBE suppliers_raw;

SELECT *
FROM suppliers_raw
WHERE supplier_id IN ('SUP001', 'SUP009', 'SUP012');

USE supply_chain_analytics;

INSERT INTO suppliers_raw
    (supplier_id, supplier_name, country, lead_time_days, reliability_score)
VALUES
    ('SUP001', 'India Supplier 1', 'Bangladesh', NULL, 0.91),
    ('SUP009', 'China Supplier 9', 'Germany', NULL, 0.76),
    ('SUP012', 'Thailand Supplier 12', 'THAILAND', 7, NULL);
    
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT supplier_id) AS unique_suppliers,
    SUM(lead_time_days IS NULL) AS missing_lead_times,
    SUM(reliability_score IS NULL) AS missing_reliability
FROM suppliers_raw;


SELECT *
FROM suppliers_raw
WHERE lead_time_days < 0
   OR country <> TRIM(country)
   OR UPPER(country) <> country;
   
   
USE supply_chain_analytics;

CREATE TABLE suppliers_clean AS
SELECT
    supplier_id,
    supplier_name,
    UPPER(TRIM(country)) AS country,
    lead_time_days,
    reliability_score,
    CASE
        WHEN lead_time_days < 0 THEN 'Review Lead Time'
        ELSE 'Valid'
    END AS lead_time_quality_flag
FROM suppliers_raw;

SELECT
    COUNT(*) AS total_suppliers,
    COUNT(DISTINCT supplier_id) AS unique_suppliers,
    SUM(lead_time_days < 0) AS negative_lead_times,
    SUM(lead_time_days IS NULL) AS missing_lead_times,
    SUM(reliability_score IS NULL) AS missing_reliability
FROM suppliers_clean;

-- Check for duplicate supplier IDs
SELECT supplier_id, COUNT(*) AS record_count
FROM suppliers_clean
GROUP BY supplier_id
HAVING COUNT(*) > 1;

-- View the final cleaned supplier data
SELECT *
FROM suppliers_clean
ORDER BY supplier_id;


USE supply_chain_analytics;

ALTER TABLE suppliers_clean
MODIFY COLUMN lead_time_quality_flag VARCHAR(30);


UPDATE suppliers_clean
SET lead_time_quality_flag = 'Missing Lead Time'
WHERE lead_time_days IS NULL;

UPDATE suppliers_clean
SET lead_time_quality_flag = 'Review Lead Time'
WHERE lead_time_days < 0;


SELECT
    supplier_id,
    lead_time_days,
    lead_time_quality_flag
FROM suppliers_clean
WHERE lead_time_days IS NULL
   OR lead_time_days < 0
ORDER BY supplier_id;


USE supply_chain_analytics;

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT supplier_id) AS unique_suppliers,
    SUM(supplier_id IS NULL OR TRIM(supplier_id) = '') AS missing_supplier_ids,
    SUM(supplier_name IS NULL OR TRIM(supplier_name) = '') AS missing_supplier_names,
    SUM(country IS NULL OR TRIM(country) = '') AS missing_countries,
    SUM(lead_time_days IS NULL) AS missing_lead_times,
    SUM(lead_time_days < 0) AS negative_lead_times,
    SUM(reliability_score IS NULL) AS missing_reliability,
    SUM(reliability_score < 0 OR reliability_score > 1) AS invalid_reliability
FROM suppliers_clean;

SELECT
    supplier_id,
    country,
    lead_time_days,
    reliability_score,
    lead_time_quality_flag
FROM suppliers_clean
ORDER BY supplier_id;


SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT supplier_id) AS unique_suppliers,
    SUM(supplier_id IS NULL OR TRIM(supplier_id) = '') AS missing_ids,
    SUM(supplier_name IS NULL OR TRIM(supplier_name) = '') AS missing_names,
    SUM(country IS NULL OR TRIM(country) = '') AS missing_countries,
    SUM(lead_time_days IS NULL) AS missing_lead_times,
    SUM(lead_time_days < 0) AS negative_lead_times,
    SUM(reliability_score IS NULL) AS missing_reliability,
    SUM(reliability_score < 0 OR reliability_score > 1) AS invalid_reliability
FROM suppliers_clean;









