SELECT
    client_id,
    transaction_id,
    product_id,
    product_quantity,
    purchase_sum,
    transaction_datetime
FROM x5_raw.purchases
WHERE client_id = '000012768d' AND transaction_id = '7e3e2e3984';


SELECT
    transaction_id,
    COUNT(*) AS line_count,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT purchase_sum) AS distinct_purchase_sum,
    MIN(SAFE_CAST(purchase_sum AS float64)) AS min_purchase_sum,
    MAX(SAFE_CAST(purchase_sum AS float64)) AS max_purchase_sum
FROM x5_raw.purchases
WHERE client_id = '000012768d'
GROUP BY transaction_id
