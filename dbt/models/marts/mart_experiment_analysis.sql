-- Session 05: observed response analytics base, ONE row per train client.
-- Treatment assignment, SMS T0 and outcome window are NOT independently verified.
-- Historical behavior is descriptive only; NOT a verified pre-SMS feature set.
-- Do not claim causal SMS uplift, revenue, ROI, or economic impact.
{{ config(materialized='table') }}

SELECT
    t.client_id,
    t.treatment_flg,
    t.target,

    -- Observed historical customer context, not intervention-time covariates.
    b.observed_snapshot_date,
    b.transactions_observed_total,
    b.recency_days_at_history_end,
    b.transactions_30d,
    b.transactions_60d,
    b.transactions_90d,
    b.active_days_30d,
    b.active_days_60d,
    b.active_days_90d
FROM {{ ref('stg_uplift_train') }} AS t
LEFT JOIN {{ ref('mart_customer_behavior_snapshot') }} AS b
    ON t.client_id = b.client_id
