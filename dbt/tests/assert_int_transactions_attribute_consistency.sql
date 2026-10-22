-- Fail closed if any source ticket attributes cannot be reduced safely.
SELECT client_id, transaction_id
FROM {{ ref('int_transactions') }}
WHERE has_store_inconsistency
   OR has_datetime_inconsistency
   OR has_purchase_sum_inconsistency
