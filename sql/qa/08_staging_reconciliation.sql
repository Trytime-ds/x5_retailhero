-- Session 3 / BigQuery console QA, execute after dbt run.
-- Snapshot of expected raw counts from Sessions 1-2; source loads must not
-- have changed since then. Staging views should retain identical row counts.
-- Uses fully-qualified names to avoid relying on the console's default project.
WITH counts AS (
    SELECT 'clients' AS entity, 400162 AS expected_count,
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_raw.clients`) AS raw_count,
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_clients`) AS staging_count
    UNION ALL
    SELECT 'products', 43038,
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_raw.products`),
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_products`)
    UNION ALL
    SELECT 'purchases', 45786568,
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_raw.purchases`),
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_purchases`)
    UNION ALL
    SELECT 'uplift_train', 200039,
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_raw.uplift_train`),
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`)
    UNION ALL
    SELECT 'uplift_test', 200123,
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_raw.uplift_test`),
        (SELECT COUNT(*) FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_test`)
)
SELECT *, raw_count = staging_count AS row_count_pass,
       raw_count = expected_count AS source_unchanged_from_baseline
FROM counts ORDER BY entity;

-- Run separately: anomalies must be retained in staging.
SELECT
    COUNT(*) AS purchase_lines,
    COUNTIF(is_zero_quantity) AS zero_quantity_lines,
    COUNTIF(is_quantity_above_review_threshold) AS qty_above_1000_lines,
    COUNTIF(is_transaction_datetime_cast_failed) AS failed_datetime_casts,
    COUNTIF(is_product_quantity_cast_failed) AS failed_quantity_casts,
    COUNTIF(is_purchase_sum_cast_failed) AS failed_purchase_sum_casts,
    COUNTIF(has_other_numeric_cast_failure) AS other_numeric_cast_failures
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_purchases`;

-- Run separately: client anomaly preservation and additional date cast QA.
SELECT
    COUNT(*) AS clients,
    COUNTIF(is_missing_age) AS missing_age,
    COUNTIF(is_age_cast_failed) AS invalid_age_cast,
    COUNTIF(age < 0) AS negative_age,
    COUNTIF(age = 0) AS zero_age,
    COUNTIF(age BETWEEN 1 AND 17) AS under_18_age,
    COUNTIF(age > 100) AS over_100_age,
    COUNTIF(is_missing_redeem_date) AS missing_redemption,
    COUNTIF(is_issue_date_cast_failed) AS invalid_issue_date_cast,
    COUNTIF(is_redeem_date_cast_failed) AS invalid_redeem_date_cast,
    COUNTIF(is_redeem_before_issue) AS redemption_before_issue
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_clients`;

-- Run separately: evaluate codes before defining their business meaning.
SELECT
    COUNT(*) AS products,
    COUNTIF(is_netto_cast_failed) AS invalid_netto,
    COUNTIF(is_own_trademark_cast_failed) AS invalid_own_code,
    COUNTIF(is_alcohol_cast_failed) AS invalid_alcohol_code,
    ARRAY_AGG(DISTINCT is_own_trademark_raw IGNORE NULLS LIMIT 20) AS own_code_examples,
    ARRAY_AGG(DISTINCT is_alcohol_raw IGNORE NULLS LIMIT 20) AS alcohol_code_examples
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_products`;
