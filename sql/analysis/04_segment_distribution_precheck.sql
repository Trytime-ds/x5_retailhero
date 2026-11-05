-- X5 RetailHero — Session 06 / Gate A: outcome-blind segment profiling
-- BigQuery Standard SQL; run the WHOLE script in region US.
-- Safe scope: ONLY client_id + observed-history frequency/recency.
-- Intentionally NO treatment_flg or target read/selected here.
-- Uses exact discrete percentiles, which preserve integer cutoff values.
-- STOP if boundaries collapse or any integrity gate is not PASS.
--
-- Result sets:
--   1) Per-dimension distribution, cutoffs, missingness, gate status
--   2) Segment membership counts and observed min/max values
-- No response rates, RD/RR, or outcome comparisons are calculated.

CREATE TEMP TABLE s6_base AS
SELECT
    client_id,
    transactions_90d,
    recency_days_at_history_end
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`;

CREATE TEMP TABLE s6_features AS
SELECT
    client_id,
    'frequency_90d' AS dimension,
    CAST(transactions_90d AS INT64) AS feature_value
FROM s6_base
UNION ALL
SELECT
    client_id,
    'recency_days' AS dimension,
    CAST(recency_days_at_history_end AS INT64) AS feature_value
FROM s6_base;

-- PERCENTILE_DISC ignores NULL by default and returns an observed value.
-- Computing boundaries over the pooled train clients avoids target-driven
-- threshold selection and does NOT imply feature timing is pre-SMS.
CREATE TEMP TABLE s6_cutoffs AS
WITH windowed AS (
    SELECT
        dimension,
        PERCENTILE_DISC(feature_value, 0.3333333333333333)
            OVER (PARTITION BY dimension) AS p33,
        PERCENTILE_DISC(feature_value, 0.5)
            OVER (PARTITION BY dimension) AS p50,
        PERCENTILE_DISC(feature_value, 0.6666666666666666)
            OVER (PARTITION BY dimension) AS p67
    FROM s6_features
)
SELECT
    dimension,
    MAX(p33) AS p33,
    MAX(p50) AS p50,
    MAX(p67) AS p67
FROM windowed
GROUP BY dimension;

CREATE TEMP TABLE s6_assignments AS
SELECT
    f.client_id,
    f.dimension,
    f.feature_value,
    c.p33,
    c.p50,
    c.p67,
    CASE
        WHEN f.feature_value IS NULL THEN 'Missing'
        WHEN c.p33 IS NULL OR c.p67 IS NULL THEN 'STOP_NO_CUTOFFS'
        WHEN c.p33 >= c.p67 THEN 'STOP_COLLAPSED_CUTOFFS'
        WHEN f.dimension = 'frequency_90d'
             AND f.feature_value <= c.p33 THEN 'Low'
        WHEN f.dimension = 'frequency_90d'
             AND f.feature_value <= c.p67 THEN 'Medium'
        WHEN f.dimension = 'frequency_90d' THEN 'High'
        WHEN f.dimension = 'recency_days'
             AND f.feature_value <= c.p33 THEN 'Recent'
        WHEN f.dimension = 'recency_days'
             AND f.feature_value <= c.p67 THEN 'Intermediate'
        WHEN f.dimension = 'recency_days' THEN 'Less recent'
        ELSE 'STOP_UNKNOWN_DIMENSION'
    END AS proposed_segment
FROM s6_features AS f
LEFT JOIN s6_cutoffs AS c USING (dimension);

-- Result set 1: inspect this BEFORE using any segment definitions.
SELECT
    dimension,
    COUNT(*) AS source_rows,
    COUNT(DISTINCT client_id) AS unique_clients,
    COUNTIF(feature_value IS NULL) AS missing_values,
    COUNTIF(feature_value = 0) AS zero_values,
    COUNTIF(feature_value < 0) AS negative_values,
    COUNT(DISTINCT feature_value) AS distinct_nonnull_values,
    MIN(feature_value) AS min_value,
    ANY_VALUE(p33) AS p33,
    ANY_VALUE(p50) AS median_p50,
    ANY_VALUE(p67) AS p67,
    MAX(feature_value) AS max_value,
    COUNTIF(feature_value = p33) AS clients_tied_at_p33,
    COUNTIF(feature_value = p67) AS clients_tied_at_p67,
    CASE
        WHEN COUNT(*) != 200039
             OR COUNT(DISTINCT client_id) != 200039
            THEN 'STOP_POPULATION_OR_GRAIN'
        WHEN COUNTIF(feature_value < 0) > 0
            THEN 'STOP_NEGATIVE_VALUES'
        WHEN dimension = 'frequency_90d'
             AND COUNTIF(feature_value IS NULL) > 0
            THEN 'STOP_MISSING_FREQUENCY'
        WHEN ANY_VALUE(p33) IS NULL OR ANY_VALUE(p67) IS NULL
            THEN 'STOP_NO_CUTOFFS'
        WHEN ANY_VALUE(p33) >= ANY_VALUE(p67)
            THEN 'STOP_COLLAPSED_CUTOFFS'
        WHEN COUNTIF(
            proposed_segment IN (
                'STOP_NO_CUTOFFS',
                'STOP_COLLAPSED_CUTOFFS',
                'STOP_UNKNOWN_DIMENSION'
            )
        ) > 0
            THEN 'STOP_ASSIGNMENT'
        ELSE 'PASS_READY_FOR_CUTOFF_REVIEW'
    END AS gate_a_status
FROM s6_assignments
GROUP BY dimension
ORDER BY dimension;

-- Result set 2: outcome-blind membership; ties remain in one segment.
-- A Missing recency group is retained (and later descriptive only).
SELECT
    dimension,
    proposed_segment,
    COUNT(*) AS clients,
    ROUND(100 * SAFE_DIVIDE(COUNT(*), 200039), 2)
        AS percent_of_train,
    MIN(feature_value) AS min_value_in_segment,
    MAX(feature_value) AS max_value_in_segment
FROM s6_assignments
GROUP BY dimension, proposed_segment
ORDER BY
    dimension,
    CASE proposed_segment
        WHEN 'Low' THEN 1
        WHEN 'Recent' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Intermediate' THEN 2
        WHEN 'High' THEN 3
        WHEN 'Less recent' THEN 3
        WHEN 'Missing' THEN 4
        ELSE 5
    END;
