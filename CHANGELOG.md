# Changelog

## 2026-10-22 — Session 04 (customer history / PR #4 pending review)

### Added
- `int_customer_purchase_history`, one row per client, with historical
  frequency, active days, store diversity, first/last purchase and
  recency relative to the **observed** history end, never SMS T0.
- Eight dbt tests (schema and singular), SQL reconciliation and contract.

### Validated (owner-executed, BigQuery US)
- `dbt run` 1/1 PASS: 400.2k rounded rows, 434.2 MiB processed,
  20.06 seconds total.
- `dbt test` 8/8 PASS; 0 warnings/errors.
- QA 8/8 TRUE: 400,162 clients and active clients, 8,045,229
  transactions, 45,786,568 product lines, 2,707,278 zero-quantity
  and 3 extreme-quantity lines, all totals reconciled.
- History-end anchor 2019-03-18; zero null anchors, bad recency
  clients or inactive clients with non-null recency.
- All 400,162 observed clients have purchase history; the
  no-purchase-client fallback is designed but not exercised.

### Boundaries
- Model gate PASS within QA scope; PR #4 awaiting review/merge.
- Business value and timing of SMS, randomization, outcome window,
  income semantics and loyalty variables remain unresolved.

## 2026-10-22 — Session 04 (transactions / PR #3 merged)

### Added
- `int_transactions` at `(client_id, transaction_id)` grain, with BigQuery
  date partitioning and client clustering.
- YAML schema, three singular dbt tests, SQL reconciliation, and
  `docs/INTERMEDIATE_CONTRACTS.md`.

### Validated (owner-executed, BigQuery US)
- `dbt run`: 1/1 PASS; 8.0m rows (rounded), 3.5 GiB processed,
  24.74 seconds total elapsed.
- `dbt test`: 10/10 PASS, 0 warnings/errors.
- QA SQL: 8,045,229 transactions; 45,786,568 source lines recovered;
  2,707,278 zero-quantity lines and 3 extreme lines preserved.
- Store/datetime/reported-purchase-sum inconsistencies: zero.
  All six reconciliation checks: TRUE.

### Boundaries and next steps
- Ticket model gate PASS within executed tests; PR #3 merged into main
  as commit `d0ea84c`.
- Source amount semantics and causal/temporal experiment validity remain open.
- Next: customer historical behavior / features design, then marts.

## 2026-10-20 — Session 03 (dbt staging / PR #2)

### Added
- Five typed one-to-one staging views, dbt source definitions and contracts.
- Preservation flags and raw-value audit fields for anomalous source values.

### Validated
- `dbt run`: 5/5 PASS; `dbt test`: 20/20 PASS.
- RAW-to-staging row counts: 5/5 exact reconciliations.
- Known purchase/client anomalies preserved; no validated cast failures.

### Limits
- Staging PASS does not establish monetary meanings, pre-treatment loyalty
  feature eligibility or experiment randomization.

## 2026-10-19 — Session 02

### Added
- SQL evidence for products key, purchase/client/product FK integrity and join cardinality.
- Risk-based quantity profiling (zeros, extreme values and vendor/category patterns).
- Client demographics and loyalty-date QA; historical time coverage checks.
- Treatment/control balance checks for gender, frequency and recency, including SMD.

### Validated
- Products: 43,038 distinct IDs in 43,038 rows; no blank/NULL IDs.
- Purchase joins: 45,786,568 rows retained, zero client or product orphans.
- Quantity: 2,707,278 zero lines; no negative/non-numeric/missing; 3 lines >1,000.
- Clients: age and loyalty-date anomalies quantified, without dropping clients.
- Historical purchases: 2018-11-21 to 2019-03-18 (118 active dates).
- Treatment/control SMD: frequency +0.0073; recency -0.0002.

### Limitations / pending
- 44,953 first redemptions occur after observed purchase-history end;
  that date is not verified campaign T0.
- Treatment assignment, exact T0 and outcome window are undocumented;
  observed treatment/control conversion difference is not established as causal.
- purchase_sum meaning, quantity units and monetary QA remain open.
- Next: dbt source declarations, staging type conversions and key data tests.

## 2026-10-16 — Session 01

### Added
- RAW ingestion scripts for five source tables.
- SQL profiling and source validation queries.
- Experimental data integrity and coverage checks.
- Initial experiment distribution analysis.

### Validated
- 45,786,568 purchase lines.
- 8,045,229 transaction groups.
- Purchase-line composite key uniqueness.
- Consistent purchase_sum within transactions.
- Complete and disjoint train/test client coverage.

### Pending at Session 01 close
- Referential integrity and additional Data Quality.
- Experiment validity and temporal leakage assessment.
- dbt staging models.
