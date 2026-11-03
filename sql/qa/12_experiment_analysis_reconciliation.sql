-- Session 05 / BigQuery US. Execute AFTER building mart_experiment_analysis.
-- Independent source -> mart reconciliation on the train population.
-- This query does NOT establish randomized assignment, intervention T0,
-- actual SMS delivery, causal uplift, or the outcome observation window.
--
-- Expected source baseline as of 2026-11-02:
-- control: 100058 clients, 60363 positive, 39695 negative;
-- treatment: 99981 clients, 63639 positive, 36342 negative.
-- All flags ending in _pass must be TRUE in BOTH rows.
-- Any source refresh requires a reviewed baseline update.

WITH expected AS (
    SELECT 0 AS treatment_flg, 100058 AS expected_clients,
           60363 AS expected_positive, 39695 AS expected_negative
    UNION ALL
    SELECT 1, 99981, 63639, 36342
),

source_by_arm AS (
    SELECT
        treatment_flg,
        COUNT(*) AS source_clients,
        COUNT(DISTINCT client_id) AS source_unique_clients,
        COUNTIF(target = 1) AS source_positive,
        COUNTIF(target = 0) AS source_negative
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`
    GROUP BY treatment_flg
),

mart_by_arm AS (
    SELECT
        treatment_flg,
        COUNT(*) AS mart_clients,
        COUNT(DISTINCT client_id) AS mart_unique_clients,
        COUNTIF(target = 1) AS mart_positive,
        COUNTIF(target = 0) AS mart_negative
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`
    GROUP BY treatment_flg
),

missing_in_mart AS (
    SELECT
        s.treatment_flg,
        COUNTIF(m.client_id IS NULL) AS missing_clients
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train` AS s
    LEFT JOIN `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis` AS m
        ON s.client_id = m.client_id
    GROUP BY s.treatment_flg
),

mart_row_qa AS (
    SELECT
        m.treatment_flg,
        COUNTIF(
            s.client_id IS NULL
            OR m.treatment_flg IS DISTINCT FROM s.treatment_flg
            OR m.target IS DISTINCT FROM s.target
        ) AS experiment_field_mismatches,
        COUNTIF(b.client_id IS NULL) AS behavior_unmatched,
        COUNTIF(
            b.client_id IS NULL
            OR m.observed_snapshot_date IS DISTINCT FROM b.observed_snapshot_date
            OR m.transactions_observed_total IS DISTINCT FROM b.transactions_observed_total
            OR m.recency_days_at_history_end IS DISTINCT FROM b.recency_days_at_history_end
            OR m.transactions_30d IS DISTINCT FROM b.transactions_30d
            OR m.transactions_60d IS DISTINCT FROM b.transactions_60d
            OR m.transactions_90d IS DISTINCT FROM b.transactions_90d
            OR m.active_days_30d IS DISTINCT FROM b.active_days_30d
            OR m.active_days_60d IS DISTINCT FROM b.active_days_60d
            OR m.active_days_90d IS DISTINCT FROM b.active_days_90d
        ) AS behavior_field_mismatches,
        COUNTIF(
            m.observed_snapshot_date IS NULL
            OR m.observed_snapshot_date != DATE '2019-03-18'
        ) AS invalid_observed_anchor
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis` AS m
    LEFT JOIN `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train` AS s
        ON m.client_id = s.client_id
    LEFT JOIN `x5-retailhero-analytics-2026.x5_dbt_dev.mart_customer_behavior_snapshot` AS b
        ON m.client_id = b.client_id
    GROUP BY m.treatment_flg
),

global_quality AS (
    SELECT
        COUNT(*) AS global_mart_rows,
        COUNT(DISTINCT client_id) AS global_unique_clients,
        COUNTIF(client_id IS NULL) AS null_client_ids,
        COUNTIF(treatment_flg IS NULL OR treatment_flg NOT IN (0, 1))
            AS invalid_treatment_rows,
        COUNTIF(target IS NULL OR target NOT IN (0, 1))
            AS invalid_target_rows
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`
)

SELECT
    COALESCE(s.treatment_flg, m.treatment_flg) AS treatment_flg,
    s.source_clients,
    m.mart_clients,
    s.source_unique_clients,
    m.mart_unique_clients,
    s.source_positive,
    m.mart_positive,
    s.source_negative,
    m.mart_negative,
    ROUND(100 * SAFE_DIVIDE(s.source_positive, s.source_clients), 4)
        AS source_response_rate_pct,
    ROUND(100 * SAFE_DIVIDE(m.mart_positive, m.mart_clients), 4)
        AS mart_response_rate_pct,
    COALESCE(missing.missing_clients, -1) AS missing_clients,
    COALESCE(q.experiment_field_mismatches, -1) AS experiment_field_mismatches,
    COALESCE(q.behavior_unmatched, -1) AS behavior_unmatched,
    COALESCE(q.behavior_field_mismatches, -1) AS behavior_field_mismatches,
    COALESCE(q.invalid_observed_anchor, -1) AS invalid_observed_anchor,
    COALESCE(
        s.source_clients = e.expected_clients
        AND s.source_positive = e.expected_positive
        AND s.source_negative = e.expected_negative, FALSE
    ) AS baseline_source_pass,
    COALESCE(
        s.source_clients = m.mart_clients
        AND s.source_positive = m.mart_positive
        AND s.source_negative = m.mart_negative, FALSE
    ) AS source_to_mart_arm_pass,
    COALESCE(
        m.mart_clients = m.mart_unique_clients
        AND m.mart_clients = s.source_unique_clients, FALSE
    ) AS unique_grain_pass,
    COALESCE(missing.missing_clients = 0, FALSE)
        AS source_coverage_pass,
    COALESCE(q.experiment_field_mismatches = 0, FALSE)
        AS experiment_fields_pass,
    COALESCE(q.behavior_unmatched = 0
             AND q.behavior_field_mismatches = 0, FALSE)
        AS behavior_alignment_pass,
    COALESCE(q.invalid_observed_anchor = 0, FALSE)
        AS observed_anchor_pass,
    (
        g.global_mart_rows = 200039
        AND g.global_unique_clients = 200039
        AND g.null_client_ids = 0
        AND g.invalid_treatment_rows = 0
        AND g.invalid_target_rows = 0
    ) AS global_population_pass
FROM source_by_arm AS s
FULL OUTER JOIN mart_by_arm AS m
    ON s.treatment_flg = m.treatment_flg
LEFT JOIN expected AS e
    ON e.treatment_flg = COALESCE(s.treatment_flg, m.treatment_flg)
LEFT JOIN missing_in_mart AS missing
    ON missing.treatment_flg = COALESCE(s.treatment_flg, m.treatment_flg)
LEFT JOIN mart_row_qa AS q
    ON q.treatment_flg = COALESCE(s.treatment_flg, m.treatment_flg)
CROSS JOIN global_quality AS g
ORDER BY treatment_flg;
