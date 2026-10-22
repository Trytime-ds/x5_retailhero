-- Grain: one row per client at the final OBSERVED purchase-history date.
-- This is a descriptive behavior snapshot, not an approved pre-SMS feature set.
-- A 30d window means snapshot date plus the prior 29 calendar dates
-- (day offsets 0..29); 60d = 0..59; 90d = 0..89.
-- Excludes unverified revenue, loyalty timestamps, treatment and outcome.
{{ config(materialized='table') }}

WITH boundary AS (
    SELECT MAX(observed_history_end_date) AS snapshot_date
    FROM {{ ref('int_customer_purchase_history') }}
),

tickets_in_90d AS (
    SELECT
        t.client_id,
        t.transaction_date,
        t.store_id,
        t.line_count,
        DATE_DIFF(b.snapshot_date, t.transaction_date, DAY)
            AS days_before_snapshot
    FROM {{ ref('int_transactions') }} AS t
    CROSS JOIN boundary AS b
    WHERE t.transaction_date BETWEEN
        DATE_SUB(b.snapshot_date, INTERVAL 89 DAY) AND b.snapshot_date
),

rolling_activity AS (
    SELECT
        client_id,
        COUNTIF(days_before_snapshot BETWEEN 0 AND 29)
            AS transactions_30d,
        COUNTIF(days_before_snapshot BETWEEN 0 AND 59)
            AS transactions_60d,
        COUNT(*) AS transactions_90d,
        COUNT(DISTINCT IF(
            days_before_snapshot BETWEEN 0 AND 29, transaction_date, NULL
        )) AS active_days_30d,
        COUNT(DISTINCT IF(
            days_before_snapshot BETWEEN 0 AND 59, transaction_date, NULL
        )) AS active_days_60d,
        COUNT(DISTINCT transaction_date) AS active_days_90d,
        COUNT(DISTINCT store_id) AS distinct_stores_90d,
        SUM(line_count) AS purchase_lines_90d
    FROM tickets_in_90d
    GROUP BY client_id
)

SELECT
    h.client_id,
    h.observed_history_end_date AS observed_snapshot_date,
    h.has_purchase_history,
    h.transaction_count AS transactions_observed_total,
    h.active_purchase_days AS active_days_observed_total,
    h.distinct_store_count AS distinct_stores_observed_total,
    h.first_purchase_date,
    h.last_purchase_date,
    h.recency_days_at_history_end,
    h.observed_purchase_span_days,
    COALESCE(r.transactions_30d, 0) AS transactions_30d,
    COALESCE(r.transactions_60d, 0) AS transactions_60d,
    COALESCE(r.transactions_90d, 0) AS transactions_90d,
    COALESCE(r.active_days_30d, 0) AS active_days_30d,
    COALESCE(r.active_days_60d, 0) AS active_days_60d,
    COALESCE(r.active_days_90d, 0) AS active_days_90d,
    COALESCE(r.distinct_stores_90d, 0) AS distinct_stores_90d,
    COALESCE(r.purchase_lines_90d, 0) AS purchase_lines_90d
FROM {{ ref('int_customer_purchase_history') }} AS h
LEFT JOIN rolling_activity AS r USING (client_id)
