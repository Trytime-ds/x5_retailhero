# Customer Purchase History — Session 04 (DRAFT)

**Status: NOT EXECUTED / NOT YET APPROVED.**
This is a proposed customer-grain intermediate model for the project owner to
review before acceptance. PR remains Draft until QA evidence and review.

## Proposed grain, universe, and semantics

- `int_customer_purchase_history`: exactly one row per
  `stg_clients.client_id`, *including clients with no observed transactions*.
  Missing activity counts are 0; unobserved purchase dates / recency are NULL.
- Build from the validated `int_transactions` plus `stg_clients`.
- Frequency = observed number of distinct client-ticket rows.
- Active days = distinct purchase calendar dates.
- Store diversity = distinct store IDs observed on tickets.
- Product-line activity = SUM(`line_count`), not purchased units.
- Zero/extreme quantity-line counts are preserved; no trimming or imputation.
- First and last transaction dates characterize the observed history.
- Recency uses global `MAX(transaction_date)` from `int_transactions` as
  an **observed history end date** (2019-03-18 in previous profiling).
  The end date is **not** verified SMS T0.
- No `purchase_sum` sums, loyalty/redemption dates, treatment or outcomes.
- Materialized as a customer-grain BigQuery table without partitioning;
  revisit clustering only with cost/performance evidence.

## QA required before gate PASS

1. One row per client; not-null, unique and exact client universe.
2. All activity totals reconcile back to `int_transactions`.
3. Zero/extreme line counts preserved.
4. Consistent observed history anchor, no negative or false zero recency.
5. No pre-treatment or causal assertions from unverified T0.

### Commands (from repo root, active virtual environment)

```bash
dbt ls --project-dir dbt --select int_customer_purchase_history
dbt run --project-dir dbt --select int_customer_purchase_history
dbt test --project-dir dbt --select int_customer_purchase_history
```

Then execute `sql/qa/10_customer_purchase_history_reconciliation.sql` in
BigQuery US and share exact values, booleans, warnings, bytes processed.

## Decisions pending owner acceptance

- Include inactive clients (recommended: YES to retain the full client universe).
- Keep recency relative to the **observed history end**, explicitly not T0
  (recommended: YES as a descriptive historical measure).
- Add rolling 30/60/90-day features only after this foundation passes.
- Avoid economic and loyalty features until semantic/temporal gates pass.
