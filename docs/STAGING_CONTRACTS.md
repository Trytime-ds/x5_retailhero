# X5 RetailHero — Staging contracts (Session 03)

Status: **PASS — technical staging gate, within the tests and reconciliations executed on 2026-10-20**.

This document records the transformation contracts and the actual validation evidence shared from local dbt and BigQuery executions. It does **not** certify experimental causal identification, feature temporal eligibility, or financial metric semantics.

## Architecture and grain

- RAW: immutable `x5_raw` sources, originally loaded as `STRING`.
- STAGING: BigQuery views in `x5_dbt_dev` by default.
- One source row to one staging row: no filters, joins, deduplication, business aggregates, or imputation.
- Source expressions use `{{ source('x5_raw', '<table>') }}` in dbt.
- Business semantics that have not been substantiated remain unresolved.

| Model | Expected grain | RAW rows | Staging rows | Row-count check |
|---|---|---:|---:|---|
| `stg_clients` | `client_id` | 400,162 | 400,162 | PASS |
| `stg_products` | `product_id` | 43,038 | 43,038 | PASS |
| `stg_purchases` | (`client_id`, `transaction_id`, `product_id`) | 45,786,568 | 45,786,568 | PASS |
| `stg_uplift_train` | `client_id` | 200,039 | 200,039 | PASS |
| `stg_uplift_test` | `client_id` | 200,123 | 200,123 | PASS |

Observed RAW counts also matched the previously recorded source benchmarks.

## Type conversion and anomaly contracts

- Clients: `age` → `INT64`; loyalty timestamps → `DATETIME`; raw strings retained for audit. Suspicious ages and chronology are flagged, never dropped.
- Products: `netto` → `NUMERIC` provisionally; `is_own_trademark` and `is_alcohol` → integer codes, with raw values retained. Codes `0` and `1` were observed; semantic confirmation is separate from type validation.
- Purchases: timestamps → `DATETIME` without inventing a timezone; quantity, ticket-level amount candidate, points and loyalty-related amounts → `NUMERIC`. Raw timestamp, quantity and amount strings retained. Zero and extreme quantities are flagged, not modified.
- Experiment: `treatment_flg` and `target` → `INT64`; `target` is a binary purchase outcome, not monetary post-campaign transaction detail.
- Failed casts of nonempty values produce a `NULL` and a corresponding diagnostic flag, wherever implemented. Missing source values remain distinct from invalid nonempty values.

## Execution evidence — 2026-10-20

Executed by the project owner on the local dbt Core 1.12.6 / dbt-bigquery 1.12.1 environment against BigQuery in US:

- `dbt run --project-dir dbt --select path:models/staging`: **PASS 5/5 views**, no errors.
- `dbt test --project-dir dbt --select path:models/staging`: **PASS 20/20 data tests**, no warnings or errors.
- `sql/qa/08_staging_reconciliation.sql`: **PASS 5/5 RAW↔staging row counts**; all RAW counts also match the documented baselines.
- `stg_purchases`: 45,786,568 lines; **2,707,278** zero-quantity lines; **3** quantity values above 1,000; **0** failed transaction datetime, quantity, amount and other evaluated numeric casts.
- `stg_clients`: 400,162 rows; **96** negative ages, **42** zero ages, **5,414** ages 1–17, **1,049** ages over 100; **35,469** missing redemption dates; **536** redemptions before issue; **0** evaluated age/date cast failures.
- `stg_products`: 43,038 rows; **0** failures converting `netto`, own-trademark and alcohol codes; observed code values `0` and `1` for both binary-like fields.

Evidence was provided as terminal and query results; the assistant did not independently run dbt or access the BigQuery tables. Passing row-count checks cannot alone prove every field value is unchanged or semantically correct.

## Tests and scope limitations

- dbt data tests: client/product/train/test key `not_null` + `unique`; purchase key components and critical numeric/date fields `not_null`; train/test clients `relationships` against customers; binary `accepted_values` for treatment and target.
- Purchase composite-key uniqueness and purchase-to-client/product integrity had previously been validated directly on RAW. These expensive checks were intentionally not duplicated in every default dbt run.
- No causal claim: assignment mechanism, communication timestamp T0 and outcome window remain unverified. The observed +3.3231 percentage point treatment/control conversion difference remains **descriptive**.
- 2019-03-18 is the end of observed purchase history, not verified intervention time; loyalty timestamps are **not** automatically eligible pre-treatment features.
- `purchase_sum` is repeated at product-line grain: do **not** sum over product lines. Monetary semantics, quantity units and some product/loyalty code semantics remain open.
- Any future model changes require rerunning dbt tests and relevant reconciliation checks.
