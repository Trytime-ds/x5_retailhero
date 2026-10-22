-- Every row must be anchored to observed purchase-history end, not system date.
WITH boundary AS (
    SELECT MAX(transaction_date) AS history_end_date
    FROM {{ ref('int_transactions') }}
)
SELECT h.client_id
FROM {{ ref('int_customer_purchase_history') }} AS h
CROSS JOIN boundary AS b
WHERE h.observed_history_end_date IS DISTINCT FROM b.history_end_date
