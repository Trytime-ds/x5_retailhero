-- Session 02 / product key profiling
-- Result reported in BigQuery: 43,038 rows; all product_id unique, nonblank, nonnull.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT TRIM(product_id)) AS unique_trimmed_ids,
    COUNTIF(TRIM(product_id) = '') AS empty_product_id,
    COUNTIF(product_id IS NULL) AS null_product_ids
FROM `x5_raw.products`;
