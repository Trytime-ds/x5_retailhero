-- Session 06 / Gate G: source-defined observed response reporting VIEW.
-- Grain: one row per analysis_scope x segment; 16 rows in current data.
-- The four scopes reuse the SAME 200,039 train clients. DO NOT sum
-- across scopes, average percentages or interpret as causal SMS uplift.
-- Historical anchor is NOT independently validated as pre-SMS T0.
{{ config(materialized='view') }}

WITH labeled AS (
    SELECT
        client_id,
        treatment_flg,
        target,
        observed_snapshot_date,
        CASE
            WHEN transactions_90d IS NULL THEN 'Missing'
            WHEN transactions_90d < 0 THEN 'Invalid'
            WHEN transactions_90d <= 8 THEN 'Low'
            WHEN transactions_90d <= 18 THEN 'Medium'
            ELSE 'High'
        END AS frequency_segment,
        CASE
            WHEN recency_days_at_history_end IS NULL THEN 'Missing'
            WHEN recency_days_at_history_end < 0 THEN 'Invalid'
            WHEN recency_days_at_history_end <= 2 THEN 'Recent'
            WHEN recency_days_at_history_end <= 7 THEN 'Intermediate'
            ELSE 'Less recent'
        END AS recency_segment
    FROM {{ ref('mart_experiment_analysis') }}
),
scope_rows AS (
    SELECT
        client_id, treatment_flg, target, observed_snapshot_date,
        'overall' AS analysis_scope,
        'All clients' AS analysis_segment,
        CAST(NULL AS STRING) AS frequency_segment,
        CAST(NULL AS STRING) AS recency_segment,
        1 AS scope_order, 0 AS segment_order
    FROM labeled
    UNION ALL
    SELECT
        client_id, treatment_flg, target, observed_snapshot_date,
        'frequency',
        CONCAT('frequency: ', frequency_segment),
        frequency_segment,
        CAST(NULL AS STRING),
        2,
        CASE frequency_segment WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2
            WHEN 'High' THEN 3 ELSE 99 END
    FROM labeled
    UNION ALL
    SELECT
        client_id, treatment_flg, target, observed_snapshot_date,
        'recency',
        CONCAT('recency: ', recency_segment),
        CAST(NULL AS STRING),
        recency_segment,
        3,
        CASE recency_segment WHEN 'Recent' THEN 1
            WHEN 'Intermediate' THEN 2 WHEN 'Less recent' THEN 3
            ELSE 99 END
    FROM labeled
    UNION ALL
    SELECT
        client_id, treatment_flg, target, observed_snapshot_date,
        'joint',
        CONCAT(frequency_segment, ' / ', recency_segment),
        frequency_segment,
        recency_segment,
        4,
        3 * (CASE frequency_segment WHEN 'Low' THEN 0
             WHEN 'Medium' THEN 1 WHEN 'High' THEN 2 ELSE 99 END)
        + CASE recency_segment WHEN 'Recent' THEN 1
             WHEN 'Intermediate' THEN 2 WHEN 'Less recent' THEN 3
             ELSE 99 END
    FROM labeled
),
scope_counts AS (
    SELECT
        analysis_scope, analysis_segment, frequency_segment,
        recency_segment, scope_order, segment_order,
        MAX(observed_snapshot_date) AS history_end_date,
        COUNT(DISTINCT observed_snapshot_date) AS distinct_history_anchors,
        COUNT(*) AS clients,
        COUNT(DISTINCT client_id) AS unique_clients,
        COUNTIF(treatment_flg = 0) AS control_n,
        COUNTIF(treatment_flg = 0 AND target = 1) AS control_positive,
        COUNTIF(treatment_flg = 0 AND target = 0) AS control_negative,
        COUNTIF(treatment_flg = 1) AS treatment_n,
        COUNTIF(treatment_flg = 1 AND target = 1) AS treatment_positive,
        COUNTIF(treatment_flg = 1 AND target = 0) AS treatment_negative
    FROM scope_rows
    GROUP BY 1,2,3,4,5,6
),
with_rates AS (
    SELECT
        *,
        SAFE_DIVIDE(control_positive, control_n) AS p0,
        SAFE_DIVIDE(treatment_positive, treatment_n) AS p1,
        CASE
            WHEN clients != unique_clients
              OR clients != control_n + treatment_n
              OR control_n != control_positive + control_negative
              OR treatment_n != treatment_positive + treatment_negative
              OR history_end_date IS NULL
              OR distinct_history_anchors != 1
              OR segment_order >= 99
                THEN 'STOP_INVALID_COUNTS'
            WHEN control_n < 500 OR treatment_n < 500
              OR control_positive < 30 OR treatment_positive < 30
              OR control_negative < 30 OR treatment_negative < 30
                THEN 'INSUFFICIENT_SUPPORT'
            ELSE 'PASS_SUPPORT'
        END AS support_status
    FROM scope_counts
),
joint_counts AS (
    SELECT
        frequency_segment,
        recency_segment,
        COUNT(*) AS clients,
        COUNTIF(treatment_flg = 0) AS n0,
        COUNTIF(treatment_flg = 0 AND target = 1) AS y0,
        COUNTIF(treatment_flg = 1) AS n1,
        COUNTIF(treatment_flg = 1 AND target = 1) AS y1
    FROM labeled
    GROUP BY 1,2
),
joint_rates AS (
    SELECT
        *,
        SAFE_DIVIDE(y0, n0) AS p0,
        SAFE_DIVIDE(y1, n1) AS p1
    FROM joint_counts
),
standardization_scopes AS (
    SELECT
        'overall' AS analysis_scope, 'All clients' AS analysis_segment,
        clients, p0, p1
    FROM joint_rates
    UNION ALL
    SELECT
        'frequency',
        CONCAT('frequency: ', frequency_segment),
        clients, p0, p1
    FROM joint_rates
    UNION ALL
    SELECT
        'recency',
        CONCAT('recency: ', recency_segment),
        clients, p0, p1
    FROM joint_rates
),
weighted AS (
    SELECT
        *,
        SAFE_DIVIDE(
            clients,
            SUM(clients) OVER (PARTITION BY analysis_scope, analysis_segment)
        ) AS common_weight
    FROM standardization_scopes
),
standardized AS (
    SELECT
        analysis_scope, analysis_segment,
        SUM(common_weight * p0) AS standardized_p0,
        SUM(common_weight * p1) AS standardized_p1,
        SUM(common_weight) AS weight_sum
    FROM weighted
    GROUP BY 1,2
)
SELECT
    CONCAT(
        r.analysis_scope, '|',
        COALESCE(r.frequency_segment, '-'), '|',
        COALESCE(r.recency_segment, '-')
    ) AS analysis_key,
    r.analysis_scope,
    r.analysis_segment,
    r.frequency_segment,
    r.recency_segment,
    r.scope_order,
    r.segment_order,
    r.history_end_date,
    r.clients,
    r.control_n,
    r.control_positive,
    r.control_negative,
    r.treatment_n,
    r.treatment_positive,
    r.treatment_negative,
    100.0 * r.p0 AS control_response_pct,
    100.0 * r.p1 AS treatment_response_pct,
    100.0 * (r.p1 - r.p0) AS observed_rd_pp,
    SAFE_DIVIDE(r.p1, r.p0) AS observed_rr,
    -- Marginal/overall only: individual Wald intervals, NOT FDR-adjusted.
    CASE
        WHEN r.analysis_scope != 'joint'
          AND r.support_status = 'PASS_SUPPORT'
        THEN 100.0 * (
            r.p1 - r.p0 - 1.95996398454 * SQRT(
                SAFE_DIVIDE(r.p1 * (1.0-r.p1), r.treatment_n)
                + SAFE_DIVIDE(r.p0 * (1.0-r.p0), r.control_n)
            )
        )
        ELSE NULL
    END AS rd_ci95_lower_pp,
    CASE
        WHEN r.analysis_scope != 'joint'
          AND r.support_status = 'PASS_SUPPORT'
        THEN 100.0 * (
            r.p1 - r.p0 + 1.95996398454 * SQRT(
                SAFE_DIVIDE(r.p1 * (1.0-r.p1), r.treatment_n)
                + SAFE_DIVIDE(r.p0 * (1.0-r.p0), r.control_n)
            )
        )
        ELSE NULL
    END AS rd_ci95_upper_pp,
    CASE
        WHEN r.analysis_scope != 'joint'
          AND r.support_status = 'PASS_SUPPORT'
          AND r.control_positive > 0 AND r.treatment_positive > 0
        THEN EXP(
            LN(SAFE_DIVIDE(r.p1, r.p0)) - 1.95996398454 * SQRT(
                1.0/r.treatment_positive - 1.0/r.treatment_n
                + 1.0/r.control_positive - 1.0/r.control_n
            )
        )
        ELSE NULL
    END AS rr_ci95_lower,
    CASE
        WHEN r.analysis_scope != 'joint'
          AND r.support_status = 'PASS_SUPPORT'
          AND r.control_positive > 0 AND r.treatment_positive > 0
        THEN EXP(
            LN(SAFE_DIVIDE(r.p1, r.p0)) + 1.95996398454 * SQRT(
                1.0/r.treatment_positive - 1.0/r.treatment_n
                + 1.0/r.control_positive - 1.0/r.control_n
            )
        )
        ELSE NULL
    END AS rr_ci95_upper,
    IF(s.weight_sum IS NOT NULL, 100.0*s.standardized_p0, NULL)
        AS pooled_std_control_response_pct,
    IF(s.weight_sum IS NOT NULL, 100.0*s.standardized_p1, NULL)
        AS pooled_std_treatment_response_pct,
    IF(s.weight_sum IS NOT NULL,
       100.0*(s.standardized_p1-s.standardized_p0), NULL)
        AS pooled_std_rd_pp,
    IF(s.weight_sum IS NOT NULL,
       SAFE_DIVIDE(s.standardized_p1,s.standardized_p0), NULL)
        AS pooled_std_rr,
    IF(s.weight_sum IS NOT NULL,
       100.0*((s.standardized_p1-s.standardized_p0)-(r.p1-r.p0)), NULL)
        AS std_minus_raw_rd_pp,
    r.support_status,
    IF(r.analysis_scope = 'joint', 'POST_HOC_DESCRIPTIVE_ONLY',
       'MARGINAL_DESCRIPTIVE_WITH_UNADJUSTED_CI') AS inference_scope,
    IF(r.analysis_scope = 'joint', CAST(NULL AS STRING),
       'WALD_RD_AND_LOG_KATZ_RR_UNADJUSTED_95') AS ci_method,
    'OBSERVED_SOURCE_DEFINED_RESPONSE_NOT_CAUSAL' AS metric_semantics,
    'T0_ASSIGNMENT_DELIVERY_OUTCOME_WINDOW_NOT_VERIFIED'
        AS causal_eligibility
FROM with_rates AS r
LEFT JOIN standardized AS s
    ON r.analysis_scope = s.analysis_scope
    AND r.analysis_segment = s.analysis_segment
