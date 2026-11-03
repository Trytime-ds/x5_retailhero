# Experiment Analysis — Contract & Gates (Session 05)

**Status:** CONTRACT APPROVED by owner (2026-11-02) / pre-build structural QA **PASS** / mart implemented in repository, **execution pending** / causal gate **NOT VERIFIED**.  
**Documented:** 2026-11-02.  
**Repository branch:** `feature/experiment-analysis-mart`.  
**Scope:** observed treatment/control response, descriptive behavioral context, and auditability.  
**Source of evidence:** user-executed BigQuery queries reported in Session 05; not re-executed by GitHub Actions or the assistant.

## 1. Business question and inference boundary

**Question for this deliverable:** What differences in observed binary response exist between the source-defined treatment and control groups, and with what statistical uncertainty under stated assumptions?

**Not established:** the incremental response *caused* by SMS, customer-level uplift, or the economic impact of a campaign.

Source metadata does not independently establish random assignment, actual exposure/delivery, campaign intervention time (T0), or the outcome observation window. The labels `treatment_flg` and `target` are retained as provided; `target=1` denotes a positive recorded outcome, but its exact post-treatment timing is not independently verified.

The purchase history ends on **2019-03-18**. This is an **observed historical cutoff, NOT verified SMS T0**. The existing 30/60/90-day customer snapshot is **descriptive, NOT an approved pre-treatment feature set**. Do not use loyalty or other potentially post-treatment data as baseline covariates without a separate temporal eligibility gate.

**Decision:** Continue with descriptive comparison (`GO WITH LIMITATIONS`); causal identification gate remains `NOT VERIFIED`.

## 2. Population, grain, and source contract

| Attribute | Contract |
|---|---|
| Grain | Exactly one row per `stg_uplift_train.client_id` |
| Population | **200,039** distinct `stg_uplift_train` clients (train only) |
| Group | `treatment_flg` INT64; 0=source-defined control, 1=source-defined treatment |
| Outcome | `target` INT64; 0=negative recorded outcome, 1=positive recorded outcome |
| Join key | `client_id`; source-defined customer identifier |
| Main source | `{{ ref('stg_uplift_train') }}` |
| Optional descriptive enrichment | `{{ ref('mart_customer_behavior_snapshot') }}`, left join on `client_id` |
| Excluded population | **200,123** `stg_uplift_test` clients; they have no observed treatment/target columns and are disjoint from train |
| Excluded fields/claims | Unvalidated revenue, ROI, ROAS, CLV, SMS causal uplift, assumed T0/outcome dates, loyalty temporal eligibility |

Do not join `stg_uplift_test` into a labeled experimental model, impute absent outcomes, or add treatment/target to the test set.

### Approved model: `mart_experiment_analysis`

**Owner-approved 2026-11-02 and implemented in versioned SQL (not yet run):** BigQuery table, one row per train client, preserving `client_id`, `treatment_flg`, `target`; left-joined descriptive historical columns listed below. Execution evidence remains pending.

The model is a **customer-level audited analysis base**. Response rates and other group aggregates belong in reproducible SQL analysis/QA, not as repeated arm-level fields on each customer row.

Candidate descriptive fields (exact upstream names):
- `observed_snapshot_date`
- `transactions_observed_total`
- `recency_days_at_history_end`
- `transactions_30d`, `transactions_60d`, `transactions_90d`
- `active_days_30d`, `active_days_60d`, `active_days_90d`

These are for **descriptive profiling only** unless pre-treatment eligibility is established separately. Do not introduce arbitrary lifecycle/RFM thresholds in this model.

## 3. Metrics and denominator contract

For each arm `g in {0,1}`:
- `n_g = COUNT(*)`, where every row is one distinct train customer in group `g`.
- `positive_g = COUNTIF(target = 1)`.
- `negative_g = COUNTIF(target = 0)`.
- `response_rate_g = positive_g / n_g`. Null or unexpected flags/outcomes must fail QA, not silently enter denominators.
- `risk_difference = response_rate_1 - response_rate_0`; report as percentage points after multiplying by 100.
- `risk_ratio = response_rate_1 / response_rate_0` when the control rate is nonzero.
- `relative_difference_pct = (risk_ratio - 1) * 100`.

Names such as “risk difference” and “risk ratio” describe contrasts **between observed groups**, not causal effects.

### Baseline — confirmed by user-executed query (2026-11-02)

| Metric | Control (0) | Treatment (1) |
|---|---:|---:|
| Customers / denominator | 100,058 | 99,981 |
| Positive outcomes | 60,363 | 63,639 |
| Negative outcomes | 39,695 | 36,342 |
| Response rate | 60.3280% | 63.6511% |

Combined totals: **200,039** customers; **124,002** positive; **76,037** negative.

Calculated from the unrounded ratios:
- Observed difference: **+3.3231 percentage points**.
- Observed risk ratio: **1.05508**.
- Observed relative rate difference: **+5.5084%**.

These are descriptive statistics and do **not** establish that SMS generated incremental purchases.

## 4. Structural and join QA evidence

### QA-01 — Experimental source population, executed by user (2026-11-02)

Source: `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`.

- `total_rows = unique_clients = 200039`.
- `null_client_ids = 0`.
- `invalid_treatment_rows = 0`.
- `invalid_target_rows = 0`.
- Source distribution and response rates match the baseline in §3.
- **Result:** Structural population QA **PASS**.

### QA-02 — Experimental → behavior snapshot left join, executed by user (2026-11-02)

Left: `stg_uplift_train`. Right: `mart_customer_behavior_snapshot`. Condition: equality of `client_id`.

| Check | Control (0) | Treatment (1) |
|---|---:|---:|
| Joined rows | 100,058 | 99,981 |
| Distinct joined clients | 100,058 | 99,981 |
| Unmatched snapshot clients | 0 | 0 |
| Missing/incorrect observed history anchor | 0 | 0 |
| Positive outcomes after join | 60,363 | 63,639 |
| Response rate after join | 60.3280% | 63.6511% |

Expected anchor in current history: `2019-03-18` (observed history end; NOT campaign T0).

- **Result:** Cardinality, match coverage, and source outcome preservation **PASS** for tested queries.
- **Not implied:** verification of each candidate behavioral field, pre-treatment status, causal exchangeability, or complete semantic suitability.

The two pre-build checks are now versioned in `sql/qa/13_experiment_population_join_precheck.sql` and the post-build independent reconciliation in `sql/qa/12_experiment_analysis_reconciliation.sql`. The historical outputs above were owner-executed before those files were versioned; **their later presence in Git does not constitute re-execution**.

## 5. Statistical analysis protocol (planned, not executed)

1. Report group-specific numerators, denominators, and observed response rates.
2. Report absolute difference (percentage points), risk ratio, and relative difference; distinguish their units.
3. Estimate confidence intervals (e.g., 95%) for group response rates and group differences using an explicitly selected method.
4. If a two-proportion test is used, document the null, test statistic, assumptions, two-sided p-value, and sample sizes. Statistical significance is **not** proof of randomization or causality.
5. Check arm balance on available historical variables as exploratory diagnostics. Previous SMD results (transaction count +0.0073, recency −0.0002) are limited descriptive evidence; **balance does not prove randomized assignment**.
6. Any heterogeneity/segment analysis needs documented segment definitions, sufficient support per arm, uncertainty estimates, and multiplicity caution or correction. Do not present exploratory subgroup differences as individualized uplift or a ready-to-deploy targeting policy.
7. Distinguish **observed result**, **assumption**, **hypothesis**, and **business decision** in the final narrative.

No financial impact estimation from `purchase_sum` or source product quantities without separate business-semantic validation.

## 6. Implementation/QA acceptance gate

Before merge, the owner must review this contract and approve the proposed customer-level model.

- [x] Contract and descriptive-only model scope approved by owner in conversation, 2026-11-02.
- [x] Draft PR #6 opened; implementation remains within that PR and branch.
- [ ] Model preserves exactly **200,039** distinct train clients; no null or duplicate `client_id`.
- [ ] Both arm counts, outcomes, and observed response rates reconcile to source exactly.
- [ ] Left join does not multiply or lose customers; descriptive anchor consistent.
- [x] dbt model/YAML and schema/singular tests implemented in GitHub branch.
- [ ] Model built and dbt tests run in BigQuery US by owner, with execution output.
- [x] Independent BigQuery reconciliation SQL committed.
- [ ] Post-build reconciliation executed; results, warnings, and processing costs recorded.
- [ ] Methodology and limitations reflected in public README/CHANGELOG/DECISIONS without overstated claims.
- [ ] Owner inspects diff and explicitly approves merge.
- [ ] Local/remote branches synchronized and cleaned after merge.

**Current gate after code publication:** `STRUCTURAL PRECHECK PASS` for the two owner-executed queries; `ANALYTICAL MODEL SQL VERSIONED — BUILD/TEST PENDING`; `EXPERIMENT CAUSAL VALIDITY NOT VERIFIED`.

## 7. Operational sequencing

1. **DONE:** Version contract on `feature/experiment-analysis-mart`, open Draft PR #6 and obtain owner approval.
2. **DONE:** Implement model, YAML/tests, and standalone source/QA queries in the same Draft PR.
3. **NEXT:** Execute dbt model/tests and BigQuery reconciliation manually; publish genuine evidence and resource costs.
5. Carry out descriptive group comparison and, if justified, uncertainty/heterogeneity analysis.
6. Merge only on owner authorization. Minimal credential-free CI is a **separate PR**; no CD in Session 05.

**Related references:** `docs/DECISIONS.md` (DEC-004, DEC-008, DEC-009, DEC-013), `docs/CUSTOMER_BEHAVIOR_SNAPSHOT_CONTRACTS.md`, `sql/qa/07_experiment_balance.sql`, `dbt/models/staging/stg_uplift_train.sql`, `dbt/models/marts/mart_customer_behavior_snapshot.sql`. Private Project Master v1.5 remains outside the public repository.
