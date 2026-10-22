# X5 RetailHero — Intermediate transaction contracts (Session 04)

**Status: PASS — transaction intermediate technical and reconciliation gate, 2026-10-22.**
Verified against the owner's local dbt Core execution and BigQuery US query
results. The assistant did not independently execute dbt or warehouse queries.
PR #3 remains subject to review and merge.

## Model and decision scope

- Model: `int_transactions`, one row per `(client_id, transaction_id)`.
- Input: `ref('stg_purchases')`, one row per original product line.
- Actual row count: **8,045,229 tickets** from **45,786,568 product lines**.
- Source and model QA observed **zero** tickets with inconsistent
  `store_id`, `transaction_datetime`, or `purchase_sum`.
- `purchase_sum_reported` takes one repeated source value per ticket;
  it is **not** validated as revenue, and the model computes neither ROI
  nor incremental spending.
- Materialization: BigQuery **table**, partitioned by
  `transaction_date = DATE(transaction_datetime)`, clustered by
  `client_id`. Source datetime timezone remains unspecified.
- Quantities are not summed into purchased units: source units are unresolved.
  The model retains line counts and zero/extreme quantity diagnostics.
- No loyalty timestamps, post-treatment outcomes, or treatment flags enter
  the historical transaction model.

## Execution evidence — 2026-10-22

| Control | Observed result | Status |
|---|---:|---|
| dbt run `int_transactions` | 1/1 model created | PASS |
| dbt test `int_transactions` | 10/10 data tests | PASS |
| Materialized rows (BigQuery reconciliation) | 8,045,229 | PASS |
| Recovered/source product lines | 45,786,568 / 45,786,568 | PASS |
| Recovered/source zero-quantity lines | 2,707,278 / 2,707,278 | PASS |
| Recovered/source extreme-quantity lines | 3 / 3 | PASS |
| Store, datetime and purchase_sum inconsistencies | 0 / 0 / 0 | PASS |
| Reconciliation booleans | 6/6 TRUE | PASS |

- `dbt run --project-dir dbt --select int_transactions` reported
  8.0m rows (rounded by dbt), **3.5 GiB processed**, and
  **24.74 seconds** total execution (model create: 16.73 seconds).
- `dbt test --project-dir dbt --select int_transactions` reported
  **10 PASS**, 0 WARN, 0 ERROR, and **17.03 seconds**.
- `sql/qa/09_intermediate_reconciliation.sql` yielded all six PASS
  booleans. This establishes aggregate reconciliation, not a row-by-row
  audit of every field.

## Quality gates and limitations

**PASS within scope:** ticket grain uniqueness, not-null mandatory fields,
source-ticket attribute consistency, derived-count ranges and full
line/anomaly aggregate preservation.

**Open outside scope:** business meaning/currency of `purchase_sum`;
`product_quantity` measurement units; campaign T0, outcome window,
randomization and causal identification. Do not interpret 2019-03-18
(the purchase-history end) as confirmed intervention time.

## Runbook (repository root)

```bash
dbt ls --project-dir dbt --select int_transactions
dbt run --project-dir dbt --select int_transactions
dbt test --project-dir dbt --select int_transactions
```

Then run `sql/qa/09_intermediate_reconciliation.sql` in BigQuery US.
PR review and merge are distinct workflow steps and must be completed
before this implementation is described as integrated into `main`.
