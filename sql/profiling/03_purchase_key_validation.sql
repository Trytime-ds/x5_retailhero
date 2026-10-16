-- X5 RetailHero | Purchase Key Validation
-- Candidate key: client_id + transaction_id + product_id

-- 1. Uniqueness validation
WITH line_keys AS (
    SELECT
        client_id,
        transaction_id,
        product_id,
        COUNT(*) AS occurrences
    FROM x5_raw.purchases
    GROUP BY 1, 2, 3
)
SELECT
    SUM(occurrences) AS total_rows,
    COUNT(*) AS distinct_keys,
    SUM(occurrences - 1) AS duplicate_excess_rows,
    COUNTIF(occurrences > 1) AS duplicated_keys,
    MAX(occurrences) AS max_occurrences
FROM line_keys;


-- 2. Key completeness validation
SELECT
    COUNTIF(
        client_id IS NULL OR TRIM(client_id) = ''
    ) AS invalid_client_ids,

    COUNTIF(
        transaction_id IS NULL OR TRIM(transaction_id) = ''
    ) AS invalid_transaction_ids,

    COUNTIF(
        product_id IS NULL OR TRIM(product_id) = ''
    ) AS invalid_product_ids

FROM x5_raw.purchases;
