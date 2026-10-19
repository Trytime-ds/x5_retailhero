-- Session 02 / quantity QA.
-- RAW values are strings; keep zero/extreme observations until semantic validation.
-- Run each SELECT separately. Read docs/DECISIONS.md for observed benchmarks.

-- Q1. Numeric validity, zero values, tails and percentiles.
WITH typed AS (
    SELECT
        product_quantity AS raw_quantity,
        SAFE_CAST(NULLIF(TRIM(product_quantity), '') AS NUMERIC) AS quantity
    FROM `x5_raw.purchases`
)
SELECT
    COUNT(*) AS total_rows,
    COUNTIF(raw_quantity IS NULL OR TRIM(raw_quantity) = '') AS missing_quantity,
    COUNTIF(raw_quantity IS NOT NULL AND TRIM(raw_quantity) != '' AND quantity IS NULL) AS invalid_numeric_quantity,
    COUNTIF(quantity = 0) AS zero_quantity,
    COUNTIF(quantity < 0) AS negative_quantity,
    COUNTIF(quantity > 0) AS positive_quantity,
    MIN(quantity) AS min_quantity,
    MAX(quantity) AS max_quantity,
    APPROX_QUANTILES(quantity, 100)[OFFSET(50)] AS approx_median,
    APPROX_QUANTILES(quantity, 1000)[OFFSET(900)] AS p90,
    APPROX_QUANTILES(quantity, 1000)[OFFSET(990)] AS p99,
    APPROX_QUANTILES(quantity, 1000)[OFFSET(999)] AS p999,
    COUNTIF(quantity > 10) AS qty_gt_10,
    COUNTIF(quantity > 100) AS qty_gt_100,
    COUNTIF(quantity > 1000) AS qty_gt_1000
FROM typed;

-- Q2. Twenty products ranked by number of zero-quantity lines.
WITH per_product AS (
    SELECT product_id, COUNT(*) AS total_lines,
           COUNTIF(SAFE_CAST(product_quantity AS NUMERIC) = 0) AS zero_lines
    FROM `x5_raw.purchases`
    GROUP BY product_id
), top_products AS (
    SELECT * FROM per_product WHERE zero_lines > 0 ORDER BY zero_lines DESC LIMIT 20
)
SELECT
    t.product_id, t.total_lines, t.zero_lines,
    ROUND(100 * SAFE_DIVIDE(t.zero_lines, t.total_lines), 2) AS zero_pct,
    pr.* EXCEPT(product_id)
FROM top_products AS t
LEFT JOIN `x5_raw.products` AS pr USING (product_id)
ORDER BY t.zero_lines DESC;

-- Q3. Investigated vendor versus the other vendors.
WITH p AS (
    SELECT product_id, COUNT(*) AS total_lines,
           COUNTIF(SAFE_CAST(product_quantity AS NUMERIC) = 0) AS zero_lines
    FROM `x5_raw.purchases`
    GROUP BY product_id
), v AS (
    SELECT IF(pr.vendor_id = 'e6af81215a', 'Investigated vendor', 'Other vendors') AS vendor_group,
           COUNT(*) AS products,
           SUM(p.total_lines) AS purchase_lines,
           SUM(p.zero_lines) AS zero_lines
    FROM p JOIN `x5_raw.products` AS pr USING (product_id)
    GROUP BY 1
)
SELECT *,
       ROUND(100 * SAFE_DIVIDE(zero_lines, purchase_lines), 2) AS zero_rate_pct,
       ROUND(100 * SAFE_DIVIDE(zero_lines, SUM(zero_lines) OVER ()), 2) AS share_all_zeros_pct,
       ROUND(100 * SAFE_DIVIDE(purchase_lines, SUM(purchase_lines) OVER ()), 2) AS share_all_purchases_pct
FROM v
ORDER BY zero_lines DESC;

-- Q4. Compare within a shared level_1/level_2 category.
WITH p AS (
    SELECT product_id, COUNT(*) AS total_lines,
           COUNTIF(SAFE_CAST(product_quantity AS NUMERIC) = 0) AS zero_lines
    FROM `x5_raw.purchases`
    GROUP BY product_id
), comparison AS (
    SELECT CASE
        WHEN pr.level_1 = 'c3d3a8e8c6' AND pr.level_2 = '034aca0659' AND pr.vendor_id = 'e6af81215a'
            THEN 'Same category - investigated vendor'
        WHEN pr.level_1 = 'c3d3a8e8c6' AND pr.level_2 = '034aca0659'
            THEN 'Same category - other vendors'
        WHEN pr.vendor_id = 'e6af81215a' THEN 'Other categories - investigated vendor'
        ELSE 'Other categories - other vendors'
    END AS comparison_group, p.total_lines, p.zero_lines
    FROM p JOIN `x5_raw.products` AS pr USING (product_id)
)
SELECT comparison_group, COUNT(*) AS products,
       SUM(total_lines) AS purchase_lines, SUM(zero_lines) AS zero_lines,
       ROUND(100 * SAFE_DIVIDE(SUM(zero_lines), SUM(total_lines)), 2) AS zero_rate_pct
FROM comparison
GROUP BY 1
ORDER BY 1;

-- Q5. Inspect rare quantity > 1,000 product lines.
-- Three lines observed in two transactions/two distinct clients.
SELECT pu.*, pr.level_1, pr.level_2, pr.level_3, pr.segment_id, pr.vendor_id, pr.netto
FROM `x5_raw.purchases` AS pu
LEFT JOIN `x5_raw.products` AS pr ON pu.product_id = pr.product_id
WHERE SAFE_CAST(pu.product_quantity AS NUMERIC) > 1000
ORDER BY SAFE_CAST(pu.product_quantity AS NUMERIC) DESC;
