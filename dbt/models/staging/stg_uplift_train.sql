-- Grain: one experimental row per client. The source does not contain T0.
WITH source_data AS (
    SELECT
        NULLIF(TRIM(client_id), '') AS client_id,
        treatment_flg AS treatment_flg_raw,
        target AS target_raw
    FROM {{ source('x5_raw', 'uplift_train') }}
),
typed AS (
    SELECT
        *,
        SAFE_CAST(NULLIF(TRIM(treatment_flg_raw), '') AS INT64) AS treatment_flg,
        SAFE_CAST(NULLIF(TRIM(target_raw), '') AS INT64) AS target
    FROM source_data
)
SELECT
    client_id,
    treatment_flg,
    target,
    treatment_flg_raw IS NOT NULL AND TRIM(treatment_flg_raw) != ''
        AND treatment_flg IS NULL AS is_treatment_cast_failed,
    target_raw IS NOT NULL AND TRIM(target_raw) != ''
        AND target IS NULL AS is_target_cast_failed
FROM typed
