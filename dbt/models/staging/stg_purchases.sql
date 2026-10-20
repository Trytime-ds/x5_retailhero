-- Grain: (client_id, transaction_id, product_id), one original purchase line.
-- purchase_sum may represent a whole ticket repeated across product lines:
-- NEVER sum purchase_sum at line grain. Semantics remain unverified.
WITH source_data AS (
    SELECT
        NULLIF(TRIM(client_id), '') AS client_id,
        NULLIF(TRIM(transaction_id), '') AS transaction_id,
        NULLIF(TRIM(product_id), '') AS product_id,
        NULLIF(TRIM(store_id), '') AS store_id,
        transaction_datetime AS transaction_datetime_raw,
        product_quantity AS product_quantity_raw,
        purchase_sum AS purchase_sum_raw,
        regular_points_received,
        express_points_received,
        regular_points_spent,
        express_points_spent,
        trn_sum_from_iss,
        trn_sum_from_red
    FROM {{ source('x5_raw', 'purchases') }}
),
typed AS (
    SELECT
        *,
        SAFE_CAST(NULLIF(TRIM(transaction_datetime_raw), '') AS DATETIME) AS transaction_datetime,
        SAFE_CAST(NULLIF(TRIM(product_quantity_raw), '') AS NUMERIC) AS product_quantity,
        SAFE_CAST(NULLIF(TRIM(purchase_sum_raw), '') AS NUMERIC) AS purchase_sum,
        SAFE_CAST(NULLIF(TRIM(regular_points_received), '') AS NUMERIC) AS regular_points_received_num,
        SAFE_CAST(NULLIF(TRIM(express_points_received), '') AS NUMERIC) AS express_points_received_num,
        SAFE_CAST(NULLIF(TRIM(regular_points_spent), '') AS NUMERIC) AS regular_points_spent_num,
        SAFE_CAST(NULLIF(TRIM(express_points_spent), '') AS NUMERIC) AS express_points_spent_num,
        SAFE_CAST(NULLIF(TRIM(trn_sum_from_iss), '') AS NUMERIC) AS trn_sum_from_iss_num,
        SAFE_CAST(NULLIF(TRIM(trn_sum_from_red), '') AS NUMERIC) AS trn_sum_from_red_num
    FROM source_data
)
SELECT
    client_id,
    transaction_id,
    product_id,
    store_id,
    transaction_datetime,
    product_quantity,
    purchase_sum,
    regular_points_received_num AS regular_points_received,
    express_points_received_num AS express_points_received,
    regular_points_spent_num AS regular_points_spent,
    express_points_spent_num AS express_points_spent,
    trn_sum_from_iss_num AS trn_sum_from_iss,
    trn_sum_from_red_num AS trn_sum_from_red,
    transaction_datetime_raw,
    product_quantity_raw,
    purchase_sum_raw,
    transaction_datetime_raw IS NOT NULL AND TRIM(transaction_datetime_raw) != ''
        AND transaction_datetime IS NULL AS is_transaction_datetime_cast_failed,
    product_quantity_raw IS NOT NULL AND TRIM(product_quantity_raw) != ''
        AND product_quantity IS NULL AS is_product_quantity_cast_failed,
    purchase_sum_raw IS NOT NULL AND TRIM(purchase_sum_raw) != ''
        AND purchase_sum IS NULL AS is_purchase_sum_cast_failed,
    product_quantity = 0 AS is_zero_quantity,
    product_quantity > 1000 AS is_quantity_above_review_threshold,
    (
        (regular_points_received IS NOT NULL AND TRIM(regular_points_received) != ''
            AND regular_points_received_num IS NULL)
        OR (express_points_received IS NOT NULL AND TRIM(express_points_received) != ''
            AND express_points_received_num IS NULL)
        OR (regular_points_spent IS NOT NULL AND TRIM(regular_points_spent) != ''
            AND regular_points_spent_num IS NULL)
        OR (express_points_spent IS NOT NULL AND TRIM(express_points_spent) != ''
            AND express_points_spent_num IS NULL)
        OR (trn_sum_from_iss IS NOT NULL AND TRIM(trn_sum_from_iss) != ''
            AND trn_sum_from_iss_num IS NULL)
        OR (trn_sum_from_red IS NOT NULL AND TRIM(trn_sum_from_red) != ''
            AND trn_sum_from_red_num IS NULL)
    ) AS has_other_numeric_cast_failure
FROM typed
