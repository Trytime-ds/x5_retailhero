-- Grain: one row per stg_clients.client_id (including clients with no history).
-- Descriptive historical behavior only; this is NOT a verified pre-SMS
-- feature snapshot because campaign T0 and outcome timing remain unverified.
-- The recency anchor is the maximum observed purchase date, never CURRENT_DATE().
{{ config(materialized='table') }}

WITH history_boundary AS (
    SELECT
        MAX(transaction_date) AS observed_history_end_date
    FROM {{ ref('int_transactions') }}
),

customer_aggregates AS (
    SELECT
        client_id,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT transaction_date) AS active_purchase_days,
        COUNT(DISTINCT store_id) AS distinct_store_count,
        MIN(transaction_date) AS first_purchase_date,
        MAX(transaction_date) AS last_purchase_date,
        SUM(line_count) AS purchase_line_count,
        SUM(zero_quantity_line_count) AS zero_quantity_line_count,
        SUM(extreme_quantity_line_count) AS extreme_quantity_line_count
    FROM {{ ref('int_transactions') }}
    GROUP BY client_id
)

SELECT
    c.client_id,
    a.client_id IS NOT NULL AS has_purchase_history,
    COALESCE(a.transaction_count, 0) AS transaction_count,
    COALESCE(a.active_purchase_days, 0) AS active_purchase_days,
    COALESCE(a.distinct_store_count, 0) AS distinct_store_count,
    COALESCE(a.purchase_line_count, 0) AS purchase_line_count,
    COALESCE(a.zero_quantity_line_count, 0) AS zero_quantity_line_count,
    COALESCE(a.extreme_quantity_line_count, 0) AS extreme_quantity_line_count,
    a.first_purchase_date,
    a.last_purchase_date,
    boundary.observed_history_end_date,
    DATE_DIFF(boundary.observed_history_end_date, a.last_purchase_date, DAY)
        AS recency_days_at_history_end,
    DATE_DIFF(a.last_purchase_date, a.first_purchase_date, DAY)
        AS observed_purchase_span_days
FROM {{ ref('stg_clients') }} AS c
CROSS JOIN history_boundary AS boundary
LEFT JOIN customer_aggregates AS a
    ON c.client_id = a.client_id
