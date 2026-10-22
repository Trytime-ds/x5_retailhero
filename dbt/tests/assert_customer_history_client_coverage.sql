-- Client universe must match the source clients exactly; no losses or additions.
SELECT c.client_id
FROM {{ ref('stg_clients') }} AS c
LEFT JOIN {{ ref('int_customer_purchase_history') }} AS h USING (client_id)
WHERE h.client_id IS NULL

UNION ALL

SELECT h.client_id
FROM {{ ref('int_customer_purchase_history') }} AS h
LEFT JOIN {{ ref('stg_clients') }} AS c USING (client_id)
WHERE c.client_id IS NULL
