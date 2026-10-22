# X5 RetailHero — Intermediate transaction contracts (Session 04)

**Status: DRAFT / NOT YET VALIDATED.** Do not mark the intermediate gate as PASS
before reviewing actual local dbt and BigQuery execution evidence.

## Model and decision scope

- Model: `int_transactions`, one row per `(client_id, transaction_id)`.
- Input: `ref('stg_purchases')`, one row per original product line.
- Historical expected output: **8,045,229 tickets** from **45,786,568 product lines**.
- Pre-build profiling on 2026-10-22 observed **zero** tickets with inconsistent
  `store_id`, `transaction_datetime`, or `purchase_sum`, and no null-store tickets.
- Reported `purchase_sum` is repeated on every source product line. Taking one
  value per ticket avoids line-count multiplication; it does **not** establish
  monetary semantics or authorize claims of revenue, ROI or incrementality.
- Date partitioning uses `DATE(transaction_datetime)` and client clustering;
  no source timezone is assumed.
- `product_quantity` is not summed as purchased units; source units are
  unresolved. Preserve counts of 0-quantity and >1000-quantity lines.
- No loyalty timestamps, post-treatment outcomes, or treatment flags enter
  this transaction-level historical model.

## Expected QA

1. Ticket grain unique and key components not null.
2. Ticket attributes consistent across source lines (singular test).
3. Derived line/product/anomaly counts satisfy range checks.
4. Reconciliation: `SUM(line_count) = 45,786,568`.
5. Anomaly preservation: `SUM(zero_quantity_line_count) = 2,707,278`;
   `SUM(extreme_quantity_line_count) = 3`.
6. All dbt runs/tests must pass, followed by
   `sql/qa/09_intermediate_reconciliation.sql` in BigQuery US.

## Runbook (from repository root)

```bash
dbt ls --project-dir dbt --select int_transactions
dbt run --project-dir dbt --select int_transactions
dbt test --project-dir dbt --select int_transactions
```

**Gate remains OPEN.** Record actual output counts, tests, runtime/cost
observations and any exceptions before final merge into main.
