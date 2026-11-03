-- Fail on missing, extra or altered train-client experimental records.
-- Joins compare client-by-client, not just coincidentally equal arm totals.
SELECT s.client_id
FROM {{ ref('stg_uplift_train') }} AS s
LEFT JOIN {{ ref('mart_experiment_analysis') }} AS m
    ON s.client_id = m.client_id
WHERE m.client_id IS NULL
   OR m.treatment_flg IS DISTINCT FROM s.treatment_flg
   OR m.target IS DISTINCT FROM s.target

UNION ALL

SELECT m.client_id
FROM {{ ref('mart_experiment_analysis') }} AS m
LEFT JOIN {{ ref('stg_uplift_train') }} AS s
    ON s.client_id = m.client_id
WHERE s.client_id IS NULL
