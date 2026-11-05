-- X5 RetailHero — Session 06 / Gate B: observed response by frozen segments
-- BigQuery Standard SQL; run the WHOLE script in region US.
--
-- Gate A cutoffs are FROZEN from owner-executed outcome-blind distributions
-- (2026-11-05). Do not adjust these values based on treatment or target.
-- Frequency_90d: Low <=8, Medium 9..18, High >=19
-- Recency_days: Recent <=2, Intermediate 3..7, Less recent >=8
-- Segments are DESCRIPTIVE only: 2019-03-18 is observed history end,
-- NOT verified SMS T0. Assignment/delivery/outcome timing not verified.
--
-- Result set 1: 6 segment comparisons, sample support and observed RD/RR.
-- Result set 2: 2 dimension-level independent source reconciliations.
-- No confidence intervals / multiple tests / causal claims at this gate.
-- IMPORTANT: do not proceed to inference if any QA status is STOP_*.

CREATE TEMP TABLE s6_frozen_segments AS
SELECT
    client_id,
    treatment_flg,
    target,
    'frequency_90d' AS dimension,
    CASE
        WHEN transactions_90d IS NULL THEN 'STOP_MISSING_FREQUENCY'
        WHEN transactions_90d < 0 THEN 'STOP_NEGATIVE_FREQUENCY'
        WHEN transactions_90d <= 8 THEN 'Low'
        WHEN transactions_90d <= 18 THEN 'Medium'
        ELSE 'High'
    END AS segment
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`
UNION ALL
SELECT
    client_id,
    treatment_flg,
    target,
    'recency_days' AS dimension,
    CASE
        WHEN recency_days_at_history_end IS NULL THEN 'Missing'
        WHEN recency_days_at_history_end < 0 THEN 'STOP_NEGATIVE_RECENCY'
        WHEN recency_days_at_history_end <= 2 THEN 'Recent'
        WHEN recency_days_at_history_end <= 7 THEN 'Intermediate'
        ELSE 'Less recent'
    END AS segment
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`;

-- Frozen segment counts are independent of outcomes.
CREATE TEMP TABLE s6_expected AS
SELECT *
FROM UNNEST([
    STRUCT('frequency_90d' AS dimension, 'Low' AS segment, 69944 AS expected_clients),
    STRUCT('frequency_90d', 'Medium', 68317),
    STRUCT('frequency_90d', 'High', 61778),
    STRUCT('recency_days', 'Recent', 76065),
    STRUCT('recency_days', 'Intermediate', 59204),
    STRUCT('recency_days', 'Less recent', 64770)
]);

CREATE TEMP TABLE s6_arm_cells AS
SELECT
    dimension,
    segment,
    treatment_flg,
    COUNT(*) AS clients,
    COUNT(DISTINCT client_id) AS unique_clients,
    COUNTIF(target = 1) AS positive,
    COUNTIF(target = 0) AS negative
FROM s6_frozen_segments
GROUP BY dimension, segment, treatment_flg;

CREATE TEMP TABLE s6_pairs AS
SELECT
    e.dimension,
    e.segment,
    e.expected_clients,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.clients, 0)), 0) AS control_n,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.positive, 0)), 0) AS control_positive,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.negative, 0)), 0) AS control_negative,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.clients, 0)), 0) AS treatment_n,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.positive, 0)), 0) AS treatment_positive,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.negative, 0)), 0) AS treatment_negative
FROM s6_expected AS e
LEFT JOIN s6_arm_cells AS c
    ON e.dimension = c.dimension AND e.segment = c.segment
GROUP BY e.dimension, e.segment, e.expected_clients;

-- Result set 1: observed arm-specific response rates and contrasts.
-- DO NOT interpret risk difference as incremental SMS effect.
SELECT
    dimension,
    segment,
    expected_clients,
    control_n + treatment_n AS observed_clients,
    control_n,
    control_positive,
    control_negative,
    ROUND(100 * SAFE_DIVIDE(control_positive, control_n), 4)
        AS control_response_pct,
    treatment_n,
    treatment_positive,
    treatment_negative,
    ROUND(100 * SAFE_DIVIDE(treatment_positive, treatment_n), 4)
        AS treatment_response_pct,
    ROUND(
        100 * (
            SAFE_DIVIDE(treatment_positive, treatment_n)
            - SAFE_DIVIDE(control_positive, control_n)
        ), 4
    ) AS observed_rd_pp,
    ROUND(
        SAFE_DIVIDE(
            SAFE_DIVIDE(treatment_positive, treatment_n),
            SAFE_DIVIDE(control_positive, control_n)
        ), 6
    ) AS observed_rr,
    CASE
        WHEN control_n + treatment_n != expected_clients
            THEN 'STOP_MEMBERSHIP_MISMATCH'
        WHEN control_n + treatment_n = 0
            THEN 'INSUFFICIENT_SUPPORT'
        WHEN control_n < 500 OR treatment_n < 500
            OR control_positive < 30 OR treatment_positive < 30
            OR control_negative < 30 OR treatment_negative < 30
            THEN 'INSUFFICIENT_SUPPORT'
        ELSE 'PASS_SUPPORT'
    END AS cell_support_status
FROM s6_pairs
ORDER BY
    dimension,
    CASE segment
        WHEN 'Low' THEN 1 WHEN 'Recent' THEN 1
        WHEN 'Medium' THEN 2 WHEN 'Intermediate' THEN 2
        WHEN 'High' THEN 3 WHEN 'Less recent' THEN 3
        ELSE 4
    END;

-- Independent SOURCE totals (not assumed equivalent to the new segment data).
CREATE TEMP TABLE s6_source_baseline AS
SELECT
    COUNT(*) AS source_clients,
    COUNT(DISTINCT client_id) AS source_unique_clients,
    COUNTIF(treatment_flg = 0) AS source_control_n,
    COUNTIF(treatment_flg = 1) AS source_treatment_n,
    COUNTIF(treatment_flg = 0 AND target = 1) AS source_control_positive,
    COUNTIF(treatment_flg = 0 AND target = 0) AS source_control_negative,
    COUNTIF(treatment_flg = 1 AND target = 1) AS source_treatment_positive,
    COUNTIF(treatment_flg = 1 AND target = 0) AS source_treatment_negative,
    COUNTIF(
        client_id IS NULL OR treatment_flg IS NULL OR target IS NULL
        OR treatment_flg NOT IN (0, 1) OR target NOT IN (0, 1)
    ) AS source_invalid_rows
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`;

CREATE TEMP TABLE s6_dim_quality AS
SELECT
    dimension,
    COUNT(*) AS assigned_rows,
    COUNT(DISTINCT client_id) AS unique_clients,
    COUNTIF(
        segment LIKE 'STOP_%' OR treatment_flg IS NULL
        OR treatment_flg NOT IN (0, 1) OR target IS NULL
        OR target NOT IN (0, 1) OR client_id IS NULL
    ) AS invalid_or_stop_rows,
    COUNTIF(segment = 'Missing') AS missing_recency_rows
FROM s6_frozen_segments
GROUP BY dimension;

CREATE TEMP TABLE s6_dim_reconciliation AS
SELECT
    dimension,
    SUM(expected_clients) AS expected_clients,
    SUM(control_n + treatment_n) AS assigned_expected_segment_clients,
    COUNTIF(control_n + treatment_n != expected_clients)
        AS segment_membership_mismatches,
    SUM(control_n) AS control_n,
    SUM(control_positive) AS control_positive,
    SUM(control_negative) AS control_negative,
    SUM(treatment_n) AS treatment_n,
    SUM(treatment_positive) AS treatment_positive,
    SUM(treatment_negative) AS treatment_negative,
    COUNTIF(
        control_n < 500 OR treatment_n < 500
        OR control_positive < 30 OR treatment_positive < 30
        OR control_negative < 30 OR treatment_negative < 30
    ) AS segments_below_support
FROM s6_pairs
GROUP BY dimension;

-- Result set 2: every dimension must independently reproduce the
-- original labeled train source arm totals and frozen segment membership.
SELECT
    q.dimension,
    q.assigned_rows,
    q.unique_clients,
    q.invalid_or_stop_rows,
    q.missing_recency_rows,
    r.expected_clients,
    r.assigned_expected_segment_clients,
    r.segment_membership_mismatches,
    r.control_n,
    r.treatment_n,
    r.control_positive,
    r.treatment_positive,
    r.control_negative,
    r.treatment_negative,
    r.segments_below_support,
    b.source_clients,
    b.source_unique_clients,
    b.source_invalid_rows,
    CASE
        WHEN b.source_clients != 200039
            OR b.source_unique_clients != 200039
            OR b.source_invalid_rows != 0
            OR q.assigned_rows != b.source_clients
            OR q.unique_clients != b.source_unique_clients
            OR q.invalid_or_stop_rows != 0
            OR q.missing_recency_rows != 0
            OR r.expected_clients != b.source_clients
            OR r.assigned_expected_segment_clients != b.source_clients
            OR r.segment_membership_mismatches != 0
            OR r.control_n != b.source_control_n
            OR r.treatment_n != b.source_treatment_n
            OR r.control_positive != b.source_control_positive
            OR r.control_negative != b.source_control_negative
            OR r.treatment_positive != b.source_treatment_positive
            OR r.treatment_negative != b.source_treatment_negative
            OR b.source_control_n != 100058
            OR b.source_treatment_n != 99981
            OR b.source_control_positive != 60363
            OR b.source_control_negative != 39695
            OR b.source_treatment_positive != 63639
            OR b.source_treatment_negative != 36342
            THEN 'STOP_RECONCILIATION'
        ELSE 'PASS_RECONCILED'
    END AS gate_b_reconciliation_status
FROM s6_dim_quality AS q
JOIN s6_dim_reconciliation AS r USING (dimension)
CROSS JOIN s6_source_baseline AS b
ORDER BY q.dimension;
