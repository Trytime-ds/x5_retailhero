# Customer Behavior Snapshot — Session 04

**State: PASS — technical and aggregate QA gate on 2026-10-22.**
Owner-executed dbt Core and BigQuery US logs received. PR #5 remains in
Draft for code review and explicit merge decision. This is not evidence
that the snapshot is a verified pre-SMS feature set.

## Grain and analytic contract

- Model: `mart_customer_behavior_snapshot`; one row for each
  `int_customer_purchase_history.client_id`: **400,162** rows.
- Reference date: last **observed** purchase-history date,
  **2019-03-18**. The actual campaign intervention T0 is unknown.
- Trailing calendar windows include the reference date:
  **30d offsets 0..29**, **60d offsets 0..59**,
  **90d offsets 0..89** (both bounds inclusive).
- Ticket counts and distinct active days in each window; distinct
  stores and original product lines in 90 days; total observed
  transactions and history recency from upstream Intermediate.
- Zero transactions in a window produce zero activity counts; a client
  with no purchases in all observed history would retain NULL recency.
  In this dataset all 400,162 clients have some historical purchase.
- Unvalidated monetary totals, `product_quantity` units, loyalty,
  SMS assignment/outcomes and business-defined lifecycle thresholds
  are excluded. The mart is descriptive and cannot support causal
  or campaign-targeting interpretations without additional gates.
- Materialization: BigQuery table, no extra partition/cluster settings.

## QA evidence — 2026-10-22

| Validation | Observed | Status |
|---|---:|---|
| dbt run | 1/1 model PASS | PASS |
| dbt test | 9/9 tests PASS; 0 WARN/ERROR | PASS |
| Source/mart customer count and uniqueness | 400,162 / 400,162 | PASS |
| Historical tickets from source/mart | 8,045,229 / 8,045,229 | PASS |
| 30-day tickets source/mart | 2,444,257 / 2,444,257 | PASS |
| 60-day tickets source/mart | 4,534,601 / 4,534,601 | PASS |
| 90-day tickets source/mart | 6,393,058 / 6,393,058 | PASS |
| 90-day product lines source/mart | 36,583,505 / 36,583,505 | PASS |
| Invalid rolling window rows | 0 | PASS |
| Observed history span | 2018-11-21 to 2019-03-18 | PASS |
| Min/max mart snapshot anchor | 2019-03-18 / 2019-03-18 | PASS |
| Independent QA query booleans | 9/9 TRUE | PASS |

- `dbt run --project-dir dbt --select mart_customer_behavior_snapshot`:
  400.2k rows as rounded in dbt CLI; **336.3 MiB processed**;
  create statement **12.31s**; total **20.63s**.
- `dbt test --project-dir dbt --select mart_customer_behavior_snapshot`:
  **9 tests PASS**; total **15.90s**; 0 WARN/ERROR.
- Reconciliation file:
  `sql/qa/11_customer_behavior_snapshot_reconciliation.sql`.
  All nine PASS flags were TRUE. Aggregate reconciliation is not a
  row-by-row equivalence proof of all fields.

## Open limitations

- Date 2019-03-18 is observed history end, not campaign T0.
- Observed 90-calendar-day span does not guarantee complete source
  observation for every customer or independent experimental validity.
- No verified randomization, treatment time, outcome window, units
  or economic semantics. No controlled campaign impact claims.
- CI was not configured for this PR; results are owner-run.
- Review/merge remains a separate approval after the validated gate.

## Reproducibility

```bash
dbt ls --project-dir dbt --select mart_customer_behavior_snapshot
dbt run --project-dir dbt --select mart_customer_behavior_snapshot
dbt test --project-dir dbt --select mart_customer_behavior_snapshot
```

Execute `sql/qa/11_customer_behavior_snapshot_reconciliation.sql`
in BigQuery US after build.
