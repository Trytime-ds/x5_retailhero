-- Session 05 / BigQuery US: observed group-level response contrasts.
-- Run AFTER mart_experiment_analysis QA has passed.
-- Uncertainty estimation / hypothesis tests are planned separately.
-- Treatment/control contrasts are descriptive, NOT proven SMS effects.

WITH arms AS (
    SELECT
        treatment_flg,
        COUNT(*) AS n,
        COUNTIF(target = 1) AS positive,
        COUNTIF(target = 0) AS negative,
        SAFE_DIVIDE(COUNTIF(target = 1), COUNT(*)) AS response_rate
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`
    GROUP BY treatment_flg
)

SELECT
    c.n AS control_clients,
    c.positive AS control_positive,
    c.negative AS control_negative,
    ROUND(100 * c.response_rate, 4) AS control_response_pct,
    t.n AS treatment_clients,
    t.positive AS treatment_positive,
    t.negative AS treatment_negative,
    ROUND(100 * t.response_rate, 4) AS treatment_response_pct,
    ROUND(100 * (t.response_rate - c.response_rate), 4)
        AS observed_difference_pp,
    ROUND(SAFE_DIVIDE(t.response_rate, c.response_rate), 6)
        AS observed_risk_ratio,
    ROUND(
        100 * (SAFE_DIVIDE(t.response_rate, c.response_rate) - 1), 4
    ) AS observed_relative_difference_pct
FROM arms AS t
CROSS JOIN arms AS c
WHERE t.treatment_flg = 1 AND c.treatment_flg = 0;
