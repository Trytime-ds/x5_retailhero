WITH clients_ids AS (
    SELECT DISTINCT TRIM(client_id) AS client_id
    FROM x5_raw.clients
    WHERE client_id IS NOT NULL
      AND TRIM(client_id) <> ''
),

train_ids AS (
    SELECT DISTINCT TRIM(client_id) AS client_id
    FROM x5_raw.uplift_train
    WHERE client_id IS NOT NULL
      AND TRIM(client_id) <> ''
),

test_ids AS (
    SELECT DISTINCT TRIM(client_id) AS client_id
    FROM x5_raw.uplift_test
    WHERE client_id IS NOT NULL
      AND TRIM(client_id) <> ''
)

SELECT
    (
        SELECT COUNT(*)
        FROM train_ids
        INNER JOIN test_ids USING (client_id)
    ) AS overlap_train_test,

    (
        SELECT COUNT(*)
        FROM clients_ids c
        LEFT JOIN train_ids t USING (client_id)
        LEFT JOIN test_ids s USING (client_id)
        WHERE t.client_id IS NULL
          AND s.client_id IS NULL
    ) AS clients_without_split,

    (
        SELECT COUNT(*)
        FROM train_ids t
        LEFT JOIN clients_ids c USING (client_id)
        WHERE c.client_id IS NULL
    ) AS train_orphans,

    (
        SELECT COUNT(*)
        FROM test_ids t
        LEFT JOIN clients_ids c USING (client_id)
        WHERE c.client_id IS NULL
    ) AS test_orphans;
