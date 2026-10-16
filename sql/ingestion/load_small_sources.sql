
-- X5 RetailHero | RAW ingestion
-- Source: GCS / raw
-- Location: US

-- 1. Products
LOAD DATA OVERWRITE
`x5-retailhero-analytics-2026.x5_raw.products`
(
    product_id STRING,
    level_1 STRING,
    level_2 STRING,
    level_3 STRING,
    level_4 STRING,
    segment_id STRING,
    brand_id STRING,
    vendor_id STRING,
    netto STRING,
    is_own_trademark STRING,
    is_alcohol STRING
)
FROM FILES (
    format = 'CSV',
    uris = ['gs://bucket-x5-retailhero/raw/products.csv.gz'],
    compression = 'GZIP',
    skip_leading_rows = 1,
    source_column_match = 'POSITION',
    max_bad_records = 0
);

-- 2. Uplift Train
LOAD DATA OVERWRITE
`x5-retailhero-analytics-2026.x5_raw.uplift_train`
(
    client_id STRING,
    treatment_flg STRING,
    target STRING
)
FROM FILES (
    format = 'CSV',
    uris = ['gs://bucket-x5-retailhero/raw/uplift_train.csv.gz'],
    compression = 'GZIP',
    skip_leading_rows = 1,
    source_column_match = 'POSITION',
    max_bad_records = 0
);

-- 3. Uplift Test
LOAD DATA OVERWRITE
`x5-retailhero-analytics-2026.x5_raw.uplift_test`
(
    client_id STRING
)
FROM FILES (
    format = 'CSV',
    uris = ['gs://bucket-x5-retailhero/raw/uplift_test.csv.gz'],
    compression = 'GZIP',
    skip_leading_rows = 1,
    source_column_match = 'POSITION',
    max_bad_records = 0
);
