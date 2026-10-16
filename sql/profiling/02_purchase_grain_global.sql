
WITH transaction_profile AS (

    SELECT
        client_id,
        transaction_id,

        COUNT(*) AS line_count,

        COUNT(
            DISTINCT SAFE_CAST(purchase_sum AS NUMERIC)
        ) AS distinct_purchase_sums,

        COUNTIF(
            SAFE_CAST(purchase_sum AS NUMERIC) IS NULL
        ) AS invalid_purchase_sums

    FROM x5_raw.purchases

    GROUP BY
        client_id,
        transaction_id
),

global_summary AS (

    SELECT
        COUNT(*) AS total_transactions,

        COUNTIF(
            line_count > 1
        ) AS multi_line_transactions,

        COUNTIF(
            distinct_purchase_sums > 1
        ) AS inconsistent_transactions,

        COUNTIF(
            invalid_purchase_sums > 0
        ) AS transactions_with_invalid_amounts

    FROM transaction_profile
)

SELECT *
FROM global_summary;
