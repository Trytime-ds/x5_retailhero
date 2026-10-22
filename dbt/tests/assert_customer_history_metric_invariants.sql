-- A failing row signals an invalid customer-grain summary.
SELECT client_id
FROM {{ ref('int_customer_purchase_history') }}
WHERE
    transaction_count < 0
    OR active_purchase_days < 0
    OR distinct_store_count < 0
    OR purchase_line_count < 0
    OR zero_quantity_line_count < 0
    OR extreme_quantity_line_count < 0
    OR active_purchase_days > transaction_count
    OR distinct_store_count > transaction_count
    OR (transaction_count > 0 AND purchase_line_count < transaction_count)
    OR zero_quantity_line_count > purchase_line_count
    OR extreme_quantity_line_count > purchase_line_count
    OR has_purchase_history IS DISTINCT FROM (transaction_count > 0)
    OR (transaction_count = 0 AND (
        first_purchase_date IS NOT NULL
        OR last_purchase_date IS NOT NULL
        OR recency_days_at_history_end IS NOT NULL
        OR observed_purchase_span_days IS NOT NULL
        OR active_purchase_days != 0
        OR distinct_store_count != 0
        OR purchase_line_count != 0
        OR zero_quantity_line_count != 0
        OR extreme_quantity_line_count != 0
    ))
    OR (transaction_count > 0 AND (
        first_purchase_date IS NULL
        OR last_purchase_date IS NULL
        OR recency_days_at_history_end IS NULL
        OR observed_purchase_span_days IS NULL
        OR recency_days_at_history_end < 0
        OR observed_purchase_span_days < 0
        OR first_purchase_date > last_purchase_date
        OR last_purchase_date > observed_history_end_date
    ))
