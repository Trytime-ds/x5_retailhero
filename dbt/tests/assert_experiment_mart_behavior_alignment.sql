-- Fail if joined descriptive behavior is missing or altered.
-- Aligning observed history does NOT establish valid pre-treatment features.
SELECT m.client_id
FROM {{ ref('mart_experiment_analysis') }} AS m
LEFT JOIN {{ ref('mart_customer_behavior_snapshot') }} AS b
    ON m.client_id = b.client_id
WHERE b.client_id IS NULL
   OR m.observed_snapshot_date IS DISTINCT FROM b.observed_snapshot_date
   OR m.transactions_observed_total IS DISTINCT FROM b.transactions_observed_total
   OR m.recency_days_at_history_end IS DISTINCT FROM b.recency_days_at_history_end
   OR m.transactions_30d IS DISTINCT FROM b.transactions_30d
   OR m.transactions_60d IS DISTINCT FROM b.transactions_60d
   OR m.transactions_90d IS DISTINCT FROM b.transactions_90d
   OR m.active_days_30d IS DISTINCT FROM b.active_days_30d
   OR m.active_days_60d IS DISTINCT FROM b.active_days_60d
   OR m.active_days_90d IS DISTINCT FROM b.active_days_90d
