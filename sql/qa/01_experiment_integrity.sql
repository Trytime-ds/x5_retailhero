WITH source_rows AS (

    SELECT
        'uplift_train' AS source,
        client_id,
        treatment_flg,
        target
    FROM x5_raw.uplift_train

    UNION ALL

    SELECT
        'uplift_test' AS source,
        client_id,
        CAST(NULL AS STRING) AS treatment_flg,
        CAST(NULL AS STRING) AS target
    FROM x5_raw.uplift_test
)

SELECT
    source,
    COUNT(*) AS total_rows,

    COUNTIF(
        client_id IS NULL OR TRIM(client_id) = ''
    ) AS invalid_client_ids,

    COUNTIF(
        client_id IS NOT NULL
        AND TRIM(client_id) <> ''
    )
    -
    COUNT(DISTINCT IF(
        client_id IS NOT NULL
        AND TRIM(client_id) <> '',
        TRIM(client_id),
        NULL
    )) AS duplicate_excess_rows,

    COUNTIF(
        source = 'uplift_train'
        AND COALESCE(TRIM(treatment_flg), '')
            NOT IN ('0', '1')
    ) AS invalid_treatment,

    COUNTIF(
        source = 'uplift_train'
        AND COALESCE(TRIM(target), '')
            NOT IN ('0', '1')
    ) AS invalid_target

FROM source_rows
GROUP BY source
ORDER BY source;
