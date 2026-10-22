-- Singular test: failure if any (client_id, transaction_id) pair repeats.
SELECT client_id, transaction_id
FROM {{ ref('int_transactions') }}
GROUP BY client_id, transaction_id
HAVING COUNT(*) > 1
