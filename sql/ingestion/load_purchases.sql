
-- X5 RetailHero | RAW ingestion
-- Source: GCS
-- Location: US

LOAD DATA OVERWRITE
`x5-retailhero-analytics-2026.x5_raw.purchases`
(
    client_id STRING,
    transaction_id STRING,
    transaction_datetime STRING,
    regular_points_received STRING,
    express_points_received STRING,
    regular_points_spent STRING,
    express_points_spent STRING,
    purchase_sum STRING,
    store_id STRING,
    product_id STRING,
    product_quantity STRING,
    trn_sum_from_iss STRING,
    trn_sum_from_red STRING
)
FROM FILES (
    format = 'CSV',
    uris = [
        'gs://bucket-x5-retailhero/raw/purchases.csv.gz'
    ],
    compression = 'GZIP',
    skip_leading_rows = 1,
    source_column_match = 'POSITION',
    max_bad_records = 0
);
