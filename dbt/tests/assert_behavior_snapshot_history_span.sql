-- Minimum observation span needed to report a 90-calendar-day window.
-- This does NOT prove completeness of every underlying day of source data.
WITH bounds AS (
    SELECT
        MIN(transaction_date) AS min_date,
        MAX(transaction_date) AS max_date
    FROM {{ ref('int_transactions') }}
)
SELECT 'insufficient_observed_span_for_90d' AS error_type
FROM bounds
WHERE min_date IS NULL
   OR max_date IS NULL
   OR DATE_DIFF(max_date, min_date, DAY) < 89
