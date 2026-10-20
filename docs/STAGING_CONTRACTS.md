# X5 RetailHero — Staging contracts (Session 03)

Status: **PROPOSED / awaiting execution**. This file records code decisions, not QA results.

## Architecture and naming

- RAW: immutable `x5_raw` sources, originally loaded as `STRING`.
- STAGING: views in `x5_dbt_dev` by default, one source row to one staging row.
- No joins, deduplication, filtering, business aggregates, causal conclusions or monetary KPIs in staging.
- Unknown business meanings are left open rather than inferred.

| Model | Expected grain | Expected source/staging rows |
|---|---|---:|
| stg_clients | `client_id` | 400,162 |
| stg_products | `product_id` | 43,038 |
| stg_purchases | (`client_id`, `transaction_id`, `product_id`) | 45,786,568 |
| stg_uplift_train | `client_id` | 200,039 |
| stg_uplift_test | `client_id` | 200,123 |

Counts are session 1/2 source benchmarks, not independently rechecked on 2026-10-20.

## Casts and anomaly contracts

- Clients: age -> `INT64`; loyalty timestamps -> `DATETIME`; input strings retained for audit. Age outside 18–100 is only a review flag and does not remove clients. Missing first redemption remains missing. Redemption-before-issue is flagged based on full datetime comparison.
- Products: `netto` -> `NUMERIC` (provisional); `is_own_trademark` and `is_alcohol` parsed as integer codes (provisional). Raw codes preserved; *do not interpret* them as true/false until actual value distributions are checked.
- Purchases: timestamps -> `DATETIME` without inventing a timezone; quantities, purchase_sum, points, trn_sum values -> `NUMERIC`. Raw transaction timestamp, quantity, amount retained. Zero and extreme quantities are flagged but not modified. Other numeric cast failures are flagged collectively for further investigation.
- Experiment: treatment and target -> `INT64`; `target` is an outcome indicator, not post-treatment monetary transaction data. `uplift_test` contains only the client ID.
- Invalid nonempty raw values that cannot be cast produce `NULL` *and a diagnostic flag*. Other nullable results can be from true source missingness and need validation.

## Gates and unresolved semantics

- No causal conclusion: assignment method not verified, exact T0 and outcome window not available. The +3.3231 pp treatment/control difference remains descriptive unless identification assumptions are defensible.
- 2019-03-18 is the end of observed purchase history, not a verified intervention time. Do not promote loyalty dates to pre-treatment features by default, even if they fall before this exploratory cutoff.
- Do not sum purchase_sum at line grain. Its economic meaning, quantity units and some loyalty/points/code semantics remain open.
- Source integrity passed in Sessions 1–2; staging tests and reconciliation are separate gates. No pass can be recorded until executed.

## Test policy

- dbt generic tests: client/product/train/test key uniqueness + not_null; purchase key components and critical numeric/date casts not_null; train/test clients in customer source; binary accepted values.
- 45.8M-line composite uniqueness and complete purchase referential integrity were validated on RAW. Do not add redundant high-cost tests to every default dbt invocation without measuring warehouse cost.
- Reconciliation script: `sql/qa/08_staging_reconciliation.sql`. Run after `dbt run`, check source/staging counts and anomalies, then examine failures before declaring staging PASS.
- SQL, schema YML and reconciliation results are prepared as a *proposed patch*. Neither dbt runs nor BigQuery checks were executed by the assistant.
