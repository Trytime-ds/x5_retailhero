-- Grain: one row per product_id. No filtering, joining, or deduplication.
-- Product weights/amounts and Boolean-like codes need semantic confirmation.
WITH source_data AS (
    SELECT
        NULLIF(TRIM(product_id), '') AS product_id,
        NULLIF(TRIM(level_1), '') AS level_1,
        NULLIF(TRIM(level_2), '') AS level_2,
        NULLIF(TRIM(level_3), '') AS level_3,
        NULLIF(TRIM(level_4), '') AS level_4,
        NULLIF(TRIM(segment_id), '') AS segment_id,
        NULLIF(TRIM(brand_id), '') AS brand_id,
        NULLIF(TRIM(vendor_id), '') AS vendor_id,
        netto AS netto_raw,
        is_own_trademark AS is_own_trademark_raw,
        is_alcohol AS is_alcohol_raw
    FROM {{ source('x5_raw', 'products') }}
),
typed AS (
    SELECT
        *,
        SAFE_CAST(NULLIF(TRIM(netto_raw), '') AS NUMERIC) AS netto,
        SAFE_CAST(NULLIF(TRIM(is_own_trademark_raw), '') AS INT64) AS is_own_trademark_code,
        SAFE_CAST(NULLIF(TRIM(is_alcohol_raw), '') AS INT64) AS is_alcohol_code
    FROM source_data
)
SELECT
    product_id,
    level_1,
    level_2,
    level_3,
    level_4,
    segment_id,
    brand_id,
    vendor_id,
    netto,
    is_own_trademark_code,
    is_alcohol_code,
    netto_raw,
    is_own_trademark_raw,
    is_alcohol_raw,
    netto_raw IS NOT NULL AND TRIM(netto_raw) != '' AND netto IS NULL AS is_netto_cast_failed,
    is_own_trademark_raw IS NOT NULL AND TRIM(is_own_trademark_raw) != ''
        AND is_own_trademark_code IS NULL AS is_own_trademark_cast_failed,
    is_alcohol_raw IS NOT NULL AND TRIM(is_alcohol_raw) != ''
        AND is_alcohol_code IS NULL AS is_alcohol_cast_failed
FROM typed
