-- Grain: one row per (client_id, transaction_id).
-- Roll up product lines to tickets; do not sum repeated purchase_sum values.
-- purchase_sum_reported is NOT a validated revenue metric.
-- Source DATETIME has unspecified timezone.
{{ config(
    materialized='table',
    partition_by={'field': 'transaction_date', 'data_type': 'date'},
    cluster_by=['client_id']
) }}

WITH tickets AS (
    SELECT
        client_id,
        transaction_id,
        -- Attribute consistency is checked explicitly below.
        MIN(store_id) AS store_id,
        MAX(transaction_datetime) AS transaction_datetime,
        DATE(MAX(transaction_datetime)) AS transaction_date,
        MAX(purchase_sum) AS purchase_sum_reported,
        COUNT(*) AS line_count,
        COUNT(DISTINCT product_id) AS distinct_product_count,
        COUNTIF(is_zero_quantity) AS zero_quantity_line_count,
        COUNTIF(is_quantity_above_review_threshold) AS extreme_quantity_line_count,
        (COUNT(DISTINCT store_id) != 1 OR COUNTIF(store_id IS NULL) > 0)
            AS has_store_inconsistency,
        (COUNT(DISTINCT transaction_datetime) != 1
            OR COUNTIF(transaction_datetime IS NULL) > 0)
            AS has_datetime_inconsistency,
        (COUNT(DISTINCT purchase_sum) != 1 OR COUNTIF(purchase_sum IS NULL) > 0)
            AS has_purchase_sum_inconsistency
    FROM {{ ref('stg_purchases') }}
    GROUP BY client_id, transaction_id
)

SELECT
    *,
    zero_quantity_line_count > 0 AS has_zero_quantity_lines,
    extreme_quantity_line_count > 0 AS has_extreme_quantity_lines
FROM tickets
