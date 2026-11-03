-- Session 05: versioned pre-build checks originally executed by owner
-- on 2026-11-02. Run each SELECT separately in BigQuery US if rechecking.
-- These checks do NOT establish pre-treatment eligibility or causal impact.

-- QA-01: Train population, response denominators and source flags.
WITH base AS (
    SELECT client_id, treatment_flg, target
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`
),
population_qa AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT client_id) AS unique_clients,
        COUNTIF(client_id IS NULL) AS null_client_ids,
        COUNTIF(treatment_flg IS NULL OR treatment_flg NOT IN (0, 1))
            AS invalid_treatment_rows,
        COUNTIF(target IS NULL OR target NOT IN (0, 1))
            AS invalid_target_rows
    FROM base
),
arm_metrics AS (
    SELECT
        treatment_flg,
        COUNT(*) AS total_clients,
        COUNTIF(target = 1) AS positive_responses,
        COUNTIF(target = 0) AS negative_responses,
        ROUND(100 * SAFE_DIVIDE(COUNTIF(target = 1), COUNT(*)), 4)
            AS response_rate_pct
    FROM base
    GROUP BY treatment_flg
)
SELECT a.*, p.*
FROM arm_metrics AS a CROSS JOIN population_qa AS p
ORDER BY a.treatment_flg;

-- QA-02: Source-defined experimental population preserved by
-- left-joining the descriptive historical behavior snapshot.
WITH joined AS (
    SELECT
        t.client_id,
        t.treatment_flg,
        t.target,
        b.client_id AS behavior_client_id,
        b.observed_snapshot_date
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train` AS t
    LEFT JOIN `x5-retailhero-analytics-2026.x5_dbt_dev.mart_customer_behavior_snapshot` AS b
        ON t.client_id = b.client_id
)
SELECT
    treatment_flg,
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT client_id) AS unique_clients,
    COUNTIF(behavior_client_id IS NULL) AS unmatched_clients,
    COUNTIF(
        observed_snapshot_date IS NULL
        OR observed_snapshot_date != DATE '2019-03-18'
    ) AS invalid_snapshot_anchor,
    COUNTIF(target = 1) AS positive_responses,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(target = 1), COUNT(*)), 4)
        AS response_rate_pct
FROM joined
GROUP BY treatment_flg
ORDER BY treatment_flg;
