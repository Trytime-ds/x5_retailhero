-- Session 05 / BigQuery US: uncertainty for observed arm-level response.
-- Run AFTER mart_experiment_analysis technical QA PASS.
-- H0: p_treatment = p_control, H1: proportions differ (two-sided).
--
-- Methods:
-- 1. Binomial response-rate intervals: unpooled Wald 95% intervals.
-- 2. Observed risk-difference interval: unpooled Wald (independent arms).
-- 3. Observed risk-ratio interval: log-normal / Katz approximation.
-- 4. Two-proportion z-test: pooled standard error under H0.
--    z > 6.466951 gives a TWO-SIDED p-value < 1e-10.
--
-- Statistical assumptions (NOT all established by source metadata):
-- observations independent between/within arms, comparable binary
-- outcome definition, and adequate large-sample normal approximations.
-- This test does NOT prove randomization, actual SMS treatment effect,
-- a verified intervention time (T0), or a verified response window.
-- Statistical association is NOT causal incrementality.
--
-- BigQuery GoogleSQL does not expose an ERFC/NORMAL_CDF mathematical
-- built-in in its documented math-function catalogue. Instead of
-- inventing an exact p-value, report z and a correctly labeled
-- two-sided p-value bound. For current counts z is far above threshold.

WITH arm_counts AS (
    SELECT
        treatment_flg,
        COUNT(*) AS n,
        COUNTIF(target = 1) AS positives,
        COUNTIF(target = 0) AS negatives
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`
    GROUP BY treatment_flg
),
pair AS (
    SELECT
        c.n AS control_n,
        c.positives AS control_positive,
        c.negatives AS control_negative,
        SAFE_DIVIDE(c.positives, c.n) AS control_p,
        t.n AS treatment_n,
        t.positives AS treatment_positive,
        t.negatives AS treatment_negative,
        SAFE_DIVIDE(t.positives, t.n) AS treatment_p
    FROM arm_counts AS c
    JOIN arm_counts AS t
        ON c.treatment_flg = 0 AND t.treatment_flg = 1
),
parameters AS (
    SELECT
        *,
        treatment_p - control_p AS observed_rd,
        SAFE_DIVIDE(treatment_p, control_p) AS observed_rr,
        SAFE_DIVIDE(
            control_positive + treatment_positive,
            control_n + treatment_n
        ) AS pooled_p,
        SQRT(
            control_p * (1 - control_p) / control_n
        ) AS control_se,
        SQRT(
            treatment_p * (1 - treatment_p) / treatment_n
        ) AS treatment_se,
        SQRT(
            control_p * (1 - control_p) / control_n
            + treatment_p * (1 - treatment_p) / treatment_n
        ) AS observed_rd_se,
        SQRT(
            1.0 / treatment_positive - 1.0 / treatment_n
            + 1.0 / control_positive - 1.0 / control_n
        ) AS log_rr_se
    FROM pair
),
statistics AS (
    SELECT
        *,
        SQRT(
            pooled_p * (1 - pooled_p)
            * (1.0 / control_n + 1.0 / treatment_n)
        ) AS pooled_se
    FROM parameters
),
test AS (
    SELECT
        *,
        SAFE_DIVIDE(observed_rd, pooled_se) AS pooled_z
    FROM statistics
)

SELECT
    control_n,
    control_positive,
    treatment_n,
    treatment_positive,
    ROUND(control_p * 100, 4) AS control_response_pct,
    ROUND((control_p - 1.959963984540054 * control_se) * 100, 4)
        AS control_ci95_lower_pct,
    ROUND((control_p + 1.959963984540054 * control_se) * 100, 4)
        AS control_ci95_upper_pct,
    ROUND(treatment_p * 100, 4) AS treatment_response_pct,
    ROUND((treatment_p - 1.959963984540054 * treatment_se) * 100, 4)
        AS treatment_ci95_lower_pct,
    ROUND((treatment_p + 1.959963984540054 * treatment_se) * 100, 4)
        AS treatment_ci95_upper_pct,
    ROUND(observed_rd * 100, 4) AS observed_rd_pp,
    ROUND((observed_rd - 1.959963984540054 * observed_rd_se) * 100, 4)
        AS observed_rd_ci95_lower_pp,
    ROUND((observed_rd + 1.959963984540054 * observed_rd_se) * 100, 4)
        AS observed_rd_ci95_upper_pp,
    ROUND(observed_rr, 6) AS observed_rr,
    ROUND(EXP(LN(observed_rr) - 1.959963984540054 * log_rr_se), 6)
        AS observed_rr_ci95_lower,
    ROUND(EXP(LN(observed_rr) + 1.959963984540054 * log_rr_se), 6)
        AS observed_rr_ci95_upper,
    ROUND(pooled_z, 4) AS z_two_sided_pooled,
    ABS(pooled_z) > 1.959963984540054 AS reject_equal_rates_at_alpha_005,
    ABS(pooled_z) > 6.466951 AS two_sided_p_below_1e_minus_10,
    (
        control_n = 100058 AND control_positive = 60363
        AND treatment_n = 99981 AND treatment_positive = 63639
    ) AS baseline_counts_match
FROM test;
