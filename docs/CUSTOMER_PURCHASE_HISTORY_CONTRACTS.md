# Customer Purchase History — Session 04

**Status: PASS — technical and aggregate QA gate (2026-10-22).**
Owner-executed dbt Core and BigQuery US results received; PR #4 remains
Draft pending review/merge. The assistant did not run dbt or BigQuery.

## Grain, universe and semantics

- `int_customer_purchase_history`: one row per `stg_clients.client_id`.
- All **400,162** source clients have an observed historical transaction.
  There are **0** clients without purchases in the current dataset.
  The left join and zero-count/NULL-date behavior for absent history are
  intentional safeguards for future source changes; this edge case did not
  occur in the validated current data.
- Build from validated `int_transactions` plus `stg_clients`.
- Frequency: observed ticket count; activity days: distinct calendar dates;
  store diversity: distinct store IDs.
- Product-line count and the counts of zero/extreme-quantity lines are
  preserved; product quantity is not interpreted as standardized units.
- First and last purchase dates describe *observed* history.
- Recency anchor: global `MAX(transaction_date)` = **2019-03-18**
  from the observed history; **this is not verified SMS T0**.
- No sums of `purchase_sum`, no unverified loyalty dates, treatment or target.
- Materialization: unpartitioned customer-grain table.
  Revisit optimization only based on query patterns and cost/performance.

## Execution and QA evidence — 2026-10-22

| Control | Actual result | Status |
|---|---:|---|
| dbt model build | 1/1 PASS | PASS |
| dbt test | 8/8 PASS, 0 WARN/ERROR | PASS |
| Client rows / distinct client IDs | 400,162 / 400,162 | PASS |
| Source client count | 400,162 | PASS |
| Source/model transaction count | 8,045,229 / 8,045,229 | PASS |
| Source/model active clients | 400,162 / 400,162 | PASS |
| Source/model purchase lines | 45,786,568 / 45,786,568 | PASS |
| Source/model zero-quantity lines | 2,707,278 / 2,707,278 | PASS |
| Source/model extreme-quantity lines | 3 / 3 | PASS |
| Min / max model history anchor | 2019-03-18 / 2019-03-18 | PASS |
| Null history anchors | 0 | PASS |
| Invalid active-client recency | 0 | PASS |
| Inactive clients with non-null recency | 0 | PASS |
| Aggregate QA booleans | 8/8 TRUE | PASS |

- `dbt run --project-dir dbt --select int_customer_purchase_history`:
  **400.2k** rows (dbt rounded), **434.2 MiB processed**,
  model statement **11.07s**, total run **20.06s**.
- `dbt test --project-dir dbt --select int_customer_purchase_history`:
  8 data tests PASS; test run **14.75s**; zero warnings/errors.
- `sql/qa/10_customer_purchase_history_reconciliation.sql`:
  8 boolean controls TRUE, source/model aggregates match exactly.

## Gate interpretation and open risks

**PASS within scope:** uniqueness, completeness against client universe,
metric invariants, observed-history date anchor, transaction/line/anomaly
aggregate reconciliation and nonnegative recency among active clients.

**Still open:** no current observations exercise behavior for clients without
purchases; purchase-history end is not confirmed treatment T0; source
amount and quantity units are unverified; experiment randomization and outcome
window remain undocumented. All customers appearing in purchase history
does not imply campaign eligibility or prove causal assumptions.

## Reproducibility

```bash
dbt ls --project-dir dbt --select int_customer_purchase_history
dbt run --project-dir dbt --select int_customer_purchase_history
dbt test --project-dir dbt --select int_customer_purchase_history
```

Then run `sql/qa/10_customer_purchase_history_reconciliation.sql` in
BigQuery US. PR review and merging are separate from model QA.
