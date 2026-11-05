-- X5 RetailHero — Session 06 / Gate D: descriptive robustness checks
-- Run WHOLE script in BigQuery US. Do not change frozen segment boundaries.
-- This diagnostic intentionally does NOT use target (outcome-blind).
-- Observed historical covariates are NOT independently certified pre-SMS.
--
-- Output 1: companion historical feature balance by segment × arm (SMD).
--   Within frequency segments -> compare recency distributions by arm.
--   Within recency segments   -> compare frequency distributions by arm.
-- Output 2: 3×3 overlap of frequency and recency, with arm composition.
-- These diagnostics assess composition, NOT randomization or causality.
-- No revenue, causal uplift, targeting decision, or post-hoc new segments.

CREATE TEMP TABLE s6_base AS
SELECT
    client_id,
    treatment_flg,
    transactions_90d,
    recency_days_at_history_end
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`;

ASSERT (
    SELECT
        COUNT(*) = 200039
        AND COUNT(DISTINCT client_id) = 200039
        AND COUNTIF(
            client_id IS NULL OR treatment_flg IS NULL
            OR treatment_flg NOT IN (0, 1)
            OR transactions_90d IS NULL OR transactions_90d < 0
            OR recency_days_at_history_end IS NULL
            OR recency_days_at_history_end < 0
        ) = 0
        AND COUNTIF(treatment_flg = 0) = 100058
        AND COUNTIF(treatment_flg = 1) = 99981
    FROM s6_base
) AS 'STOP: observed population / arm totals / history feature QA changed';

CREATE TEMP TABLE s6_labeled AS
SELECT
    client_id,
    treatment_flg,
    transactions_90d,
    recency_days_at_history_end,
    CASE
        WHEN transactions_90d <= 8 THEN 'Low'
        WHEN transactions_90d <= 18 THEN 'Medium'
        ELSE 'High'
    END AS frequency_segment,
    CASE
        WHEN recency_days_at_history_end <= 2 THEN 'Recent'
        WHEN recency_days_at_history_end <= 7 THEN 'Intermediate'
        ELSE 'Less recent'
    END AS recency_segment
FROM s6_base;

CREATE TEMP TABLE s6_long AS
SELECT
    client_id, treatment_flg,
    'frequency_90d' AS dimension,
    frequency_segment AS segment,
    CAST(recency_days_at_history_end AS FLOAT64) AS companion_metric
FROM s6_labeled
UNION ALL
SELECT
    client_id, treatment_flg,
    'recency_days' AS dimension,
    recency_segment AS segment,
    CAST(transactions_90d AS FLOAT64) AS companion_metric
FROM s6_labeled;

-- Freeze evidence: all six segment sizes must still match owner Gate A.
ASSERT (
    WITH counts AS (
        SELECT dimension, segment, COUNT(*) AS n
        FROM s6_long
        GROUP BY dimension, segment
    ), reference AS (
        SELECT * FROM UNNEST([
            STRUCT('frequency_90d' AS dimension, 'Low' AS segment, 69944 AS n),
            STRUCT('frequency_90d', 'Medium', 68317),
            STRUCT('frequency_90d', 'High', 61778),
            STRUCT('recency_days', 'Recent', 76065),
            STRUCT('recency_days', 'Intermediate', 59204),
            STRUCT('recency_days', 'Less recent', 64770)
        ])
    )
    SELECT COUNT(*) = 6
        AND COUNTIF(c.n IS NULL OR c.n != r.n) = 0
    FROM reference AS r
    LEFT JOIN counts AS c USING (dimension, segment)
) AS 'STOP: frozen segment membership no longer matches Gate A';

CREATE TEMP TABLE s6_companion_arm AS
SELECT
    dimension, segment, treatment_flg,
    COUNT(*) AS clients,
    AVG(companion_metric) AS mean_companion,
    STDDEV_POP(companion_metric) AS sd_companion,
    APPROX_QUANTILES(companion_metric, 100)[OFFSET(50)] AS median_companion
FROM s6_long
GROUP BY dimension, segment, treatment_flg;

CREATE TEMP TABLE s6_companion_comparison AS
SELECT
    c.dimension,
    c.segment,
    c.clients AS control_n,
    t.clients AS treatment_n,
    c.mean_companion AS control_mean,
    t.mean_companion AS treatment_mean,
    c.median_companion AS control_median,
    t.median_companion AS treatment_median,
    c.sd_companion AS sd_control,
    t.sd_companion AS sd_treatment,
    SAFE_DIVIDE(
        t.mean_companion - c.mean_companion,
        SQRT((POW(c.sd_companion, 2) + POW(t.sd_companion, 2)) / 2.0)
    ) AS standardized_mean_difference
FROM s6_companion_arm AS c
JOIN s6_companion_arm AS t
    ON c.dimension = t.dimension
    AND c.segment = t.segment
WHERE c.treatment_flg = 0 AND t.treatment_flg = 1;

-- Result 1: subgroup compositional/balance diagnostic.
-- |SMD| >= 0.1 is a review flag, not a formal randomization test.
SELECT
    dimension, segment,
    CASE
        WHEN dimension = 'frequency_90d' THEN 'recency_days_at_history_end'
        ELSE 'transactions_90d'
    END AS companion_feature,
    control_n, treatment_n,
    ROUND(control_mean, 4) AS control_mean,
    ROUND(treatment_mean, 4) AS treatment_mean,
    control_median, treatment_median,
    ROUND(standardized_mean_difference, 6) AS companion_smd,
    CASE
        WHEN standardized_mean_difference IS NULL THEN 'REVIEW_UNDEFINED_SMD'
        WHEN ABS(standardized_mean_difference) >= 0.1 THEN 'REVIEW_IMBALANCE'
        ELSE 'NO_LARGE_SMD_OBSERVED'
    END AS diagnostic_status
FROM s6_companion_comparison
ORDER BY
    dimension,
    CASE segment
        WHEN 'Low' THEN 1 WHEN 'Recent' THEN 1
        WHEN 'Medium' THEN 2 WHEN 'Intermediate' THEN 2
        WHEN 'High' THEN 3 WHEN 'Less recent' THEN 3
        ELSE 4
    END;

-- Result 2: descriptive frequency × recency overlap (NO target column).
-- Reveals whether the two separate segment dimensions are correlated.
SELECT
    frequency_segment,
    recency_segment,
    COUNT(*) AS clients,
    COUNTIF(treatment_flg = 0) AS control_n,
    COUNTIF(treatment_flg = 1) AS treatment_n,
    ROUND(
        100 * SAFE_DIVIDE(COUNTIF(treatment_flg = 0), 100058), 4
    ) AS share_within_all_control_pct,
    ROUND(
        100 * SAFE_DIVIDE(COUNTIF(treatment_flg = 1), 99981), 4
    ) AS share_within_all_treatment_pct,
    ROUND(
        100 * (
            SAFE_DIVIDE(COUNTIF(treatment_flg = 1), 99981)
            - SAFE_DIVIDE(COUNTIF(treatment_flg = 0), 100058)
        ), 4
    ) AS treatment_minus_control_mix_pp
FROM s6_labeled
GROUP BY frequency_segment, recency_segment
ORDER BY
    CASE frequency_segment
        WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2 ELSE 3
    END,
    CASE recency_segment
        WHEN 'Recent' THEN 1 WHEN 'Intermediate' THEN 2 ELSE 3
    END;
