-- Fail if treatment x target counts diverge from staging.
-- This tests source parity, not assignment validity or causal impact.
WITH source_counts AS (
    SELECT treatment_flg, target, COUNT(*) AS n
    FROM {{ ref('stg_uplift_train') }}
    GROUP BY 1, 2
),
mart_counts AS (
    SELECT treatment_flg, target, COUNT(*) AS n
    FROM {{ ref('mart_experiment_analysis') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(s.treatment_flg, m.treatment_flg) AS treatment_flg,
    COALESCE(s.target, m.target) AS target,
    s.n AS source_count,
    m.n AS mart_count
FROM source_counts AS s
FULL OUTER JOIN mart_counts AS m
    ON s.treatment_flg = m.treatment_flg AND s.target = m.target
WHERE s.n IS DISTINCT FROM m.n
