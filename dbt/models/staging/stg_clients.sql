-- Grain: one row per client_id. No filtering, joining, or deduplication.
-- Loyalty event dates are NOT assumed pre-treatment; do not consume them as
-- predictive features before the temporal suitability gate is resolved.
WITH source_data AS (
    SELECT
        NULLIF(TRIM(client_id), '') AS client_id,
        age AS age_raw,
        NULLIF(UPPER(TRIM(gender)), '') AS gender,
        first_issue_date AS first_issue_date_raw,
        first_redeem_date AS first_redeem_date_raw
    FROM {{ source('x5_raw', 'clients') }}
),
typed AS (
    SELECT
        *,
        SAFE_CAST(NULLIF(TRIM(age_raw), '') AS INT64) AS age,
        SAFE_CAST(NULLIF(TRIM(first_issue_date_raw), '') AS DATETIME) AS first_issue_datetime,
        SAFE_CAST(NULLIF(TRIM(first_redeem_date_raw), '') AS DATETIME) AS first_redeem_datetime
    FROM source_data
)
SELECT
    client_id,
    gender,
    age,
    first_issue_datetime,
    first_redeem_datetime,
    age_raw,
    first_issue_date_raw,
    first_redeem_date_raw,
    age_raw IS NULL OR TRIM(age_raw) = '' AS is_missing_age,
    age_raw IS NOT NULL AND TRIM(age_raw) != '' AND age IS NULL AS is_age_cast_failed,
    age IS NOT NULL AND (age < 18 OR age > 100) AS is_age_outside_review_range,
    first_issue_date_raw IS NOT NULL AND TRIM(first_issue_date_raw) != ''
        AND first_issue_datetime IS NULL AS is_issue_date_cast_failed,
    first_redeem_date_raw IS NULL OR TRIM(first_redeem_date_raw) = '' AS is_missing_redeem_date,
    first_redeem_date_raw IS NOT NULL AND TRIM(first_redeem_date_raw) != ''
        AND first_redeem_datetime IS NULL AS is_redeem_date_cast_failed,
    first_redeem_datetime < first_issue_datetime AS is_redeem_before_issue
FROM typed
