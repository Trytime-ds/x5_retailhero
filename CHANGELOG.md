# Changelog

## 2026-11-02 — Session 05 (experiment response mart / Draft PR #6)

### Added and technically validated
- Owner-approved `docs/EXPERIMENT_ANALYSIS_CONTRACTS.md` for 200,039
  labeled train customers, one row per client.
- `mart_experiment_analysis`, YAML and singular dbt tests for client/arm/outcome
  parity and descriptive snapshot alignment.
- `sql/qa/12_experiment_analysis_reconciliation.sql` (post-build),
  `sql/qa/13_experiment_population_join_precheck.sql` (previously
  owner-executed checks now versioned), and
  `sql/analysis/02_experiment_observed_response.sql` (owner-executed),
  and `sql/analysis/03_experiment_response_inference.sql` for 95% CIs
  and a two-sided z-test (**owner-executed; reconciled to independent reference**).

### Evidence and boundaries
- Owner-executed **pre-build** BigQuery checks: 200,039 distinct train IDs;
  0 invalid flags or targets; preserved 100,058 control and 99,981
  treatment clients on join, with 0 unmatched history clients.
- Source-defined response rates: control 60.3280%, treatment 63.6511%;
  observed difference +3.3231 percentage points (NOT causal).
- **Owner-run model execution:** `dbt run` 1/1 PASS, 15.55 s;
  `dbt test` 17/17 PASS, 20.77 s; zero WARN/ERROR.
- **Owner-run post-build reconciliation:** both arms match source counts
  and response rates exactly, zero missing/mismatched clients and
  behavior fields, zero invalid historical anchors; **16/16 TRUE**
  (eight checks per arm). Total unique mart clients: 200,039.
- **Owner-run inferential SQL:** difference +3.3231 pp, 95% CI
  [+2.8979, +3.7483] pp; RR 1.055084, 95% CI
  [1.047861, 1.062356]; pooled z=15.3093, two-sided p < 1e-10.
  All three inferential boolean checks TRUE; owner-reported BigQuery
  values match independent arithmetic reference.
- These intervals and p-value are conditional on approximate
  independent-binomial inference, **not an identified causal SMS effect**.
- Bytes processed / monetary cost not yet supplied. Draft PR #6
  remains unmerged, pending owner review.
- No evidence of randomized assignment, verified SMS T0 or exact outcome
  window; no SMS incremental revenue or uplift claim.

### Session 04 status correction (verified on 2026-11-02)
- PR #5 was actually merged to main on 2026-10-22 (squash `435e96a`).
  Original contemporaneous “pending review” notes below describe the
  pre-merge status, not the repository's current state.

## 2026-10-22 — Session 04 (behavior mart / PR #5 pending review)

### Added
- `mart_customer_behavior_snapshot` with one row per customer, observed
  total activity and inclusive 30/60/90-day ticket/active-day windows.
- Three singular dbt tests, schema contracts, BigQuery QA reconciliation
  and an explicit observed-history (not T0) temporal contract.

### Validated (owner-executed, BigQuery US)
- `dbt run` 1/1 PASS; 400.2k CLI-rounded rows; 336.3 MiB processed;
  20.63s total, of which 12.31s in model statement.
- `dbt test` 9/9 PASS; 0 WARN/ERROR; 15.90s total.
- BigQuery reconciliations 9/9 TRUE: customer universe 400,162;
  8,045,229 all-history tickets; 2,444,257 / 4,534,601 /
  6,393,058 tickets over 30/60/90 days; 36,583,505 90d lines.
- Snapshot 2019-03-18, observed first date 2018-11-21;
  no invalid window rows. PR #5 remains under review.

### Boundaries
- Observed calendar cutoff is not verified SMS T0.
  This descriptive mart does not establish causal feature eligibility,
  unvalidated revenue, product units or treatment impact.

## 2026-10-22 — Session 04 (customer history / PR #4 merged)

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
- Model gate PASS within QA scope; PR #4 merged into main
  as commit `83566a0`.
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
