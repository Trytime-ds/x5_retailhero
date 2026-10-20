-- Grain: one scoring row per client. Do not join to train here.
SELECT
    NULLIF(TRIM(client_id), '') AS client_id
FROM {{ source('x5_raw', 'uplift_test') }}
