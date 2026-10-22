-- Fail on lost clients or mismatched all-history facts / anchors.
SELECT h.client_id
FROM {{ ref('int_customer_purchase_history') }} AS h
LEFT JOIN {{ ref('mart_customer_behavior_snapshot') }} AS m USING (client_id)
WHERE m.client_id IS NULL
   OR m.observed_snapshot_date IS DISTINCT FROM h.observed_history_end_date
   OR m.transactions_observed_total IS DISTINCT FROM h.transaction_count
   OR m.active_days_observed_total IS DISTINCT FROM h.active_purchase_days
   OR m.distinct_stores_observed_total IS DISTINCT FROM h.distinct_store_count
   OR m.recency_days_at_history_end IS DISTINCT FROM h.recency_days_at_history_end
   OR m.first_purchase_date IS DISTINCT FROM h.first_purchase_date
   OR m.last_purchase_date IS DISTINCT FROM h.last_purchase_date
   OR m.has_purchase_history IS DISTINCT FROM h.has_purchase_history
UNION ALL
SELECT m.client_id
FROM {{ ref('mart_customer_behavior_snapshot') }} AS m
LEFT JOIN {{ ref('int_customer_purchase_history') }} AS h USING (client_id)
WHERE h.client_id IS NULL
