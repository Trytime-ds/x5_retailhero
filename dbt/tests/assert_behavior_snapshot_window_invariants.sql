-- Fail when trailing windows, activity or recency relations are inconsistent.
SELECT client_id
FROM {{ ref('mart_customer_behavior_snapshot') }}
WHERE
    transactions_observed_total IS NULL
    OR transactions_30d IS NULL
    OR transactions_60d IS NULL
    OR transactions_90d IS NULL
    OR active_days_30d IS NULL
    OR active_days_60d IS NULL
    OR active_days_90d IS NULL
    OR distinct_stores_90d IS NULL
    OR purchase_lines_90d IS NULL
    OR transactions_30d < 0
    OR transactions_30d > transactions_60d
    OR transactions_60d > transactions_90d
    OR transactions_90d > transactions_observed_total
    OR active_days_30d < 0
    OR active_days_30d > active_days_60d
    OR active_days_60d > active_days_90d
    OR active_days_90d > active_days_observed_total
    OR active_days_30d > transactions_30d
    OR active_days_60d > transactions_60d
    OR active_days_90d > transactions_90d
    OR distinct_stores_90d < 0
    OR distinct_stores_90d > transactions_90d
    OR distinct_stores_90d > distinct_stores_observed_total
    OR purchase_lines_90d < transactions_90d
    OR (transactions_90d = 0 AND purchase_lines_90d != 0)
    OR (
        recency_days_at_history_end IS NOT NULL
        AND (
            (recency_days_at_history_end BETWEEN 0 AND 89)
            IS DISTINCT FROM (transactions_90d > 0)
        )
    )
