-- X5 RetailHero | Session 06 | Gate C: conditional descriptive inference
-- Run entire script in BigQuery US. Assumes owner-run Gate B PASS (2026-11-05).
-- NO causal SMS-effect identification: randomization, delivery, T0 and target
-- window are unverified; history cutoff is NOT verified pre-treatment.
--
-- Confidence intervals: Wald (unpooled RD), log-Katz (RR), 95% two-sided.
-- Within-segment H0: equal source-defined response proportions; pooled z.
-- Heterogeneity H0: RD(segment) = RD(reference); unpooled z for two
-- disjoint segment RDs in SAME dimension (reference Low/Recent).
-- BH-FDR at alpha=0.05: family A six segment tests, family B four
-- heterogeneity contrasts. Same customers occur across dimensions; results
-- are exploratory, correlated and conditional on model assumptions.
--
-- GoogleSQL has no native normal CDF. The two-sided p below uses the
-- Numerical Recipes erfc normal-tail approximation; report as
-- APPROXIMATE, not an exact p-value. Reference checked against erfc in
-- independent arithmetic (relative error under 1e-6 on the six observed z).
-- Output set 1: 6 per-segment RD/RR, 95% CIs, z, p, BH q.
-- Output set 2: 4 difference-in-RDs vs fixed reference, 95% CIs, p, BH q.

-- Two-sided normal tail p = erfc(|z| / sqrt(2)).
-- This stable erfc approximation avoids cancellation from 1-Phi(|z|).
CREATE TEMP FUNCTION erfc_t(z FLOAT64) AS (
    SAFE_DIVIDE(1.0, 1.0 + 0.5 * ABS(z) / SQRT(2.0))
);
CREATE TEMP FUNCTION erfc_poly(t FLOAT64) AS (
    -1.26551223
    + t * (1.00002368
    + t * (0.37409196
    + t * (0.09678418
    + t * (-0.18628806
    + t * (0.27886807
    + t * (-1.13520398
    + t * (1.48851587
    + t * (-0.82215223
    + t * 0.17087277))))))))
);
CREATE TEMP FUNCTION normal_two_sided_p_approx(z FLOAT64) AS (
    IF(
        z IS NULL,
        NULL,
        LEAST(1.0, GREATEST(0.0,
            erfc_t(z) * EXP(-0.5 * POW(z, 2)
                + erfc_poly(erfc_t(z)))
        ))
    )
);

CREATE TEMP TABLE s6_experiment AS
SELECT
    client_id,
    treatment_flg,
    target,
    transactions_90d,
    recency_days_at_history_end
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`;

ASSERT (
    SELECT
        COUNT(*) = 200039
        AND COUNT(DISTINCT client_id) = 200039
        AND COUNTIF(
            client_id IS NULL
            OR treatment_flg IS NULL OR treatment_flg NOT IN (0, 1)
            OR target IS NULL OR target NOT IN (0, 1)
            OR transactions_90d IS NULL OR transactions_90d < 0
            OR recency_days_at_history_end IS NULL
            OR recency_days_at_history_end < 0
        ) = 0
    FROM s6_experiment
) AS 'STOP: base grain, labels, missingness or history features changed';

CREATE TEMP TABLE s6_segmented AS
SELECT
    client_id, treatment_flg, target,
    'frequency_90d' AS dimension,
    CASE
        WHEN transactions_90d <= 8 THEN 'Low'
        WHEN transactions_90d <= 18 THEN 'Medium'
        ELSE 'High'
    END AS segment
FROM s6_experiment
UNION ALL
SELECT
    client_id, treatment_flg, target,
    'recency_days' AS dimension,
    CASE
        WHEN recency_days_at_history_end <= 2 THEN 'Recent'
        WHEN recency_days_at_history_end <= 7 THEN 'Intermediate'
        ELSE 'Less recent'
    END AS segment
FROM s6_experiment;

CREATE TEMP TABLE s6_expected_segments AS
SELECT * FROM UNNEST([
    STRUCT('frequency_90d' AS dimension, 'Low' AS segment,
        69944 AS expected_n, 1 AS sort_order),
    STRUCT('frequency_90d', 'Medium', 68317, 2),
    STRUCT('frequency_90d', 'High', 61778, 3),
    STRUCT('recency_days', 'Recent', 76065, 1),
    STRUCT('recency_days', 'Intermediate', 59204, 2),
    STRUCT('recency_days', 'Less recent', 64770, 3)
]);

CREATE TEMP TABLE s6_cells AS
SELECT
    dimension, segment, treatment_flg,
    COUNT(*) AS n,
    COUNTIF(target = 1) AS positive,
    COUNTIF(target = 0) AS negative
FROM s6_segmented
GROUP BY dimension, segment, treatment_flg;

CREATE TEMP TABLE s6_pairs AS
SELECT
    e.dimension, e.segment, e.sort_order, e.expected_n,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.n, 0)), 0) AS n0,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.positive, 0)), 0) AS y0,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.negative, 0)), 0) AS neg0,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.n, 0)), 0) AS n1,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.positive, 0)), 0) AS y1,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.negative, 0)), 0) AS neg1
FROM s6_expected_segments AS e
LEFT JOIN s6_cells AS c
    ON e.dimension = c.dimension AND e.segment = c.segment
GROUP BY e.dimension, e.segment, e.sort_order, e.expected_n;

-- Stop instead of silently dropping any segment / relaxing thresholds.
ASSERT (
    SELECT
        COUNT(*) = 6
        AND COUNTIF(
            n0 + n1 != expected_n
            OR n0 < 500 OR n1 < 500
            OR y0 < 30 OR y1 < 30
            OR neg0 < 30 OR neg1 < 30
            OR y0 + neg0 != n0 OR y1 + neg1 != n1
        ) = 0
    FROM s6_pairs
) AS 'STOP: frozen membership or minimum support gate no longer holds';

ASSERT (
    WITH totals AS (
        SELECT
            dimension,
            SUM(n0) AS n0, SUM(n1) AS n1,
            SUM(y0) AS y0, SUM(y1) AS y1,
            SUM(neg0) AS neg0, SUM(neg1) AS neg1
        FROM s6_pairs
        GROUP BY dimension
    )
    SELECT
        COUNT(*) = 2
        AND COUNTIF(
            n0 != 100058 OR n1 != 99981
            OR y0 != 60363 OR y1 != 63639
            OR neg0 != 39695 OR neg1 != 36342
        ) = 0
    FROM totals
) AS 'STOP: segment data do not reconcile to source arm baseline';

CREATE TEMP TABLE s6_stats AS
WITH rates AS (
    SELECT
        *,
        SAFE_DIVIDE(y0, n0) AS p0,
        SAFE_DIVIDE(y1, n1) AS p1,
        SAFE_DIVIDE(y0 + y1, n0 + n1) AS pooled_p
    FROM s6_pairs
), v AS (
    SELECT
        *,
        p1 - p0 AS rd,
        SAFE_DIVIDE(p1, p0) AS rr,
        SQRT(
            SAFE_DIVIDE(p1 * (1.0 - p1), n1)
            + SAFE_DIVIDE(p0 * (1.0 - p0), n0)
        ) AS se_rd,
        SQRT(
            pooled_p * (1.0 - pooled_p)
            * (SAFE_DIVIDE(1.0, n1) + SAFE_DIVIDE(1.0, n0))
        ) AS se_pooled,
        SQRT(
            SAFE_DIVIDE(1.0, y1) - SAFE_DIVIDE(1.0, n1)
            + SAFE_DIVIDE(1.0, y0) - SAFE_DIVIDE(1.0, n0)
        ) AS se_log_rr
    FROM rates
)
SELECT
    *,
    SAFE_DIVIDE(rd, se_pooled) AS z_equal_rates,
    normal_two_sided_p_approx(SAFE_DIVIDE(rd, se_pooled))
        AS p_within_approx
FROM v;

CREATE TEMP TABLE s6_heterogeneity AS
SELECT
    a.dimension,
    a.segment,
    b.segment AS reference_segment,
    a.sort_order,
    a.rd AS segment_rd,
    b.rd AS reference_rd,
    a.rd - b.rd AS difference_in_rd,
    SQRT(POW(a.se_rd, 2) + POW(b.se_rd, 2)) AS se_diff_rd,
    SAFE_DIVIDE(
        a.rd - b.rd,
        SQRT(POW(a.se_rd, 2) + POW(b.se_rd, 2))
    ) AS z_heterogeneity,
    normal_two_sided_p_approx(
        SAFE_DIVIDE(
            a.rd - b.rd,
            SQRT(POW(a.se_rd, 2) + POW(b.se_rd, 2))
        )
    ) AS p_heterogeneity_approx
FROM s6_stats AS a
JOIN s6_stats AS b
    ON a.dimension = b.dimension
    AND b.sort_order = 1
WHERE a.sort_order > 1;

CREATE TEMP TABLE s6_tests AS
SELECT
    'A_within_segment' AS family,
    CONCAT(dimension, '|', segment) AS test_id,
    p_within_approx AS p_value
FROM s6_stats
UNION ALL
SELECT
    'B_between_segment_RD' AS family,
    CONCAT(dimension, '|', segment) AS test_id,
    p_heterogeneity_approx AS p_value
FROM s6_heterogeneity;

ASSERT (
    SELECT COUNT(*) = 10
        AND COUNTIF(p_value IS NULL OR p_value < 0 OR p_value > 1) = 0
    FROM s6_tests
) AS 'STOP: incorrect multiplicity family or invalid approximate p-value';

-- BH step-up: q_i = min_{j>=i}(m*p_(j)/j), capped at 1.
-- Rank ascending by p; reverse ordering for suffix cumulative MIN.
CREATE TEMP TABLE s6_adjusted_p AS
WITH ranked AS (
    SELECT
        *,
        COUNT(*) OVER (PARTITION BY family) AS m,
        ROW_NUMBER() OVER (
            PARTITION BY family ORDER BY p_value, test_id
        ) AS p_rank
    FROM s6_tests
), adjusted AS (
    SELECT
        *,
        LEAST(1.0, p_value * m / p_rank) AS bh_raw
    FROM ranked
)
SELECT
    family, test_id, p_value, m, p_rank,
    MIN(bh_raw) OVER (
        PARTITION BY family
        ORDER BY p_value DESC, test_id DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS bh_fdr_q
FROM adjusted;

-- Result 1: segment-level contrasts. Within-segment significance does
-- NOT constitute a test of heterogeneity (see result 2).
SELECT
    s.dimension, s.segment,
    s.n0 AS control_n, s.y0 AS control_positive,
    s.n1 AS treatment_n, s.y1 AS treatment_positive,
    ROUND(100 * s.p0, 4) AS control_response_pct,
    ROUND(100 * s.p1, 4) AS treatment_response_pct,
    ROUND(100 * s.rd, 4) AS observed_rd_pp,
    ROUND(100 * (s.rd - 1.95996398454 * s.se_rd), 4)
        AS rd_ci95_lower_pp,
    ROUND(100 * (s.rd + 1.95996398454 * s.se_rd), 4)
        AS rd_ci95_upper_pp,
    ROUND(s.rr, 6) AS observed_rr,
    ROUND(EXP(LN(s.rr) - 1.95996398454 * s.se_log_rr), 6)
        AS rr_ci95_lower,
    ROUND(EXP(LN(s.rr) + 1.95996398454 * s.se_log_rr), 6)
        AS rr_ci95_upper,
    ROUND(s.z_equal_rates, 4) AS pooled_z,
    s.p_within_approx AS two_sided_p_approx,
    a.bh_fdr_q AS family_a_bh_q,
    a.bh_fdr_q < 0.05 AS family_a_bh_significant
FROM s6_stats AS s
JOIN s6_adjusted_p AS a
    ON a.family = 'A_within_segment'
    AND a.test_id = CONCAT(s.dimension, '|', s.segment)
ORDER BY s.dimension, s.sort_order;

-- Result 2: differences between RDs, referenced to Low or Recent.
-- These are descriptive heterogeneity tests, NOT causal interactions.
SELECT
    h.dimension,
    h.segment,
    h.reference_segment,
    ROUND(100 * h.segment_rd, 4) AS segment_rd_pp,
    ROUND(100 * h.reference_rd, 4) AS reference_rd_pp,
    ROUND(100 * h.difference_in_rd, 4) AS delta_rd_pp,
    ROUND(
        100 * (h.difference_in_rd - 1.95996398454 * h.se_diff_rd), 4
    ) AS delta_rd_ci95_lower_pp,
    ROUND(
        100 * (h.difference_in_rd + 1.95996398454 * h.se_diff_rd), 4
    ) AS delta_rd_ci95_upper_pp,
    ROUND(h.z_heterogeneity, 4) AS z_heterogeneity,
    h.p_heterogeneity_approx AS two_sided_p_approx,
    a.bh_fdr_q AS family_b_bh_q,
    a.bh_fdr_q < 0.05 AS family_b_bh_significant
FROM s6_heterogeneity AS h
JOIN s6_adjusted_p AS a
    ON a.family = 'B_between_segment_RD'
    AND a.test_id = CONCAT(h.dimension, '|', h.segment)
ORDER BY h.dimension, h.sort_order;
