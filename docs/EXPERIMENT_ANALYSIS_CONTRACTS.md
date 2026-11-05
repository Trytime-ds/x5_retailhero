# Experiment Analysis — Contract & Gates (Session 05)

> **Repository status correction (2026-11-05):** PR #6 was squash-merged
> into `main` on 2026-11-02 (Chile time), commit `6210d9c`.
> Any references in this Session 05 historical contract to pending
> owner PR review, an unmerged Draft, or a not-yet-executed model
> describe the state **before** execution/merge. The actual
> owner-executed model and inference PASS evidence is recorded below.
> This status correction does not modify the experimental limitations.


**Status:** CONTRACT APPROVED / technical QA **PASS** / descriptive response inference **PASS under stated assumptions** (owner-executed 2026-11-02) / owner PR review **PENDING** / causal gate **NOT VERIFIED**.  
**Documented:** 2026-11-02.  
**Repository branch:** `feature/experiment-analysis-mart`.  
**Scope:** observed treatment/control response, descriptive behavioral context, and auditability.  
**Source of evidence:** owner-reported BigQuery and dbt CLI outputs from Session 05; not independently re-executed by GitHub Actions or the assistant. Actual bytes processed and monetary costs were not supplied.

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

## 5. Statistical analysis protocol (aggregate comparison completed)

### Post-build technical execution evidence — owner-reported (2026-11-02)

- `dbt run --select mart_experiment_analysis`: **1/1 PASS**, **0 WARN, 0 ERROR**, execution time **15.55 s**.
- `dbt test --select mart_experiment_analysis`: **17/17 PASS**, **0 WARN, 0 ERROR, 0 SKIP**, execution time **20.77 s**.
- `sql/qa/12_experiment_analysis_reconciliation.sql`: **2 arm rows returned**. Both arms matched source counts, source-positive and negative outcomes, source-to-mart rates, and historical context.
- Per-arm QA: `missing_clients = 0`, `experiment_field_mismatches = 0`, `behavior_unmatched = 0`, `behavior_field_mismatches = 0`, `invalid_observed_anchor = 0`.
- All **eight** `*_pass` flags **TRUE** on both arms (**16 TRUE results**). Distinct clients in the mart = **200,039**.
- **Not measured/reported yet:** warehouse bytes processed and charges; these must not be fabricated. `dbt debug` output and CI execution have not been independently evidenced. Inferential outputs are now owner-reported below.

These PASS results validate model integrity under the specified checks, **not** SMS incrementality, intervention timing, randomization, or causal identification.

1. Report group-specific numerators, denominators, and observed response rates.
2. Report absolute difference (percentage points), risk ratio, and relative difference; distinguish their units.
3. Estimate confidence intervals (e.g., 95%) for group response rates and group differences using an explicitly selected method.
4. If a two-proportion test is used, document the null, test statistic, assumptions, two-sided p-value, and sample sizes. Statistical significance is **not** proof of randomization or causality.
5. Check arm balance on available historical variables as exploratory diagnostics. Previous SMD results (transaction count +0.0073, recency −0.0002) are limited descriptive evidence; **balance does not prove randomized assignment**.
6. Any heterogeneity/segment analysis needs documented segment definitions, sufficient support per arm, uncertainty estimates, and multiplicity caution or correction. Do not present exploratory subgroup differences as individualized uplift or a ready-to-deploy targeting policy.
7. Distinguish **observed result**, **assumption**, **hypothesis**, and **business decision** in the final narrative.

No financial impact estimation from `purchase_sum` or source product quantities without separate business-semantic validation.

### Reproducible inference query (versioned and owner-executed, 2026-11-02)

`sql/analysis/03_experiment_response_inference.sql` calculates:

- Normal-approximation (Wald) 95% CI for each observed binary response rate, using each arm's binomial standard error.
- Unpooled Wald 95% CI for the **observed** treatment-minus-control difference (percentage points).
- Log-normal (Katz) 95% CI for the **observed** risk ratio; this requires nonzero positive outcomes in both arms.
- Two-sided pooled-variance z-statistic for H0: population response proportions are equal; compares to critical z = ±1.959964 for alpha = 0.05.
- A conservative binary significance marker indicating **two-sided p < 1e-10** if |z| > 6.466951; BigQuery SQL does not claim an exact p-value from unavailable built-in normal-tail functions.

The analysis assumes independent binary observations, group comparability, and large-sample approximations. Those inferential assumptions are **conditional**; they do not validate an unknown assignment mechanism or campaign chronology.

**Independent arithmetic reference from verified arm counts, reproduced exactly in owner-executed BigQuery SQL:**

| Metric | Approximate expected value |
|---|---:|
| Control response-rate 95% CI | 60.0249% to 60.6311% |
| Treatment response-rate 95% CI | 63.3529% to 63.9492% |
| Observed difference 95% CI | **+2.8979 to +3.7483 percentage points** |
| Observed RR 95% CI | 1.047861 to 1.062356 |
| Pooled z statistic (two-sided) | +15.3093 |
| Two-sided p-value implication | p < 1e-10 (approximate external calculation: ~6.6e-53) |

**Owner-reported BigQuery outputs (2026-11-02):** source counts reproduced exactly (control n=100,058; positive=60,363; treatment n=99,981; positive=63,639). All output values matched the independent reference after rounding to display precision: control rate 60.3280% (95% CI [60.0249%, 60.6311%]); treatment rate 63.6511% (95% CI [63.3529%, 63.9492%]); RD +3.3231 pp (95% CI [+2.8979, +3.7483] pp); RR 1.055084 (95% CI [1.047861, 1.062356]); pooled z=15.3093. `reject_equal_rates_at_alpha_005=true`, `two_sided_p_below_1e_minus_10=true`, `baseline_counts_match=true`.

**Inferential QA: PASS** for the aggregate descriptive contrast, conditional on the independent-binomial model and large-sample assumptions. The query reports a bound **p < 1e-10**, not an exact p-value. These are **not causal-effect confidence intervals**, and statistical significance does not establish randomized assignment, SMS exposure, correct temporal eligibility, or incremental SMS impact.

## 6. Implementation/QA acceptance gate

Before merge, the owner must review this contract and approve the proposed customer-level model.

- [x] Contract and descriptive-only model scope approved by owner in conversation, 2026-11-02.
- [x] Draft PR #6 opened; implementation remains within that PR and branch.
- [x] Model preserves exactly **200,039** distinct train clients; no null or duplicate `client_id` (owner-run reconciliations and tests).
- [x] Both arm counts, outcomes, and observed response rates reconcile to source exactly.
- [x] Left join does not multiply or lose customers; descriptive anchor consistent.
- [x] dbt model/YAML and schema/singular tests implemented in GitHub branch.
- [x] Model built and dbt tests run by owner: **dbt run 1/1 PASS; dbt test 17/17 PASS**.
- [x] Independent BigQuery reconciliation SQL committed.
- [x] Post-build reconciliation executed: **16/16 TRUE**, no missing/mismatched clients or fields.
- [ ] Actual bytes processed / cost evidence recorded (not yet supplied).
- [x] Technical and inferential QA evidence and limitations reflected in public README/CHANGELOG/DECISIONS without causal overclaims.
- [x] Aggregated response, 95% rate/RD/RR intervals, and two-sided z-test reproduced in owner-executed BigQuery query.
- [ ] Owner inspects diff and explicitly approves merge.
- [ ] Local/remote branches synchronized and cleaned after merge.

**Current gate after owner execution:** `PRECHECK PASS`; `DBT MODEL BUILD 1/1 PASS`; `DBT TEST 17/17 PASS`; `POST-BUILD RECONCILIATION 16/16 TRUE`; `DESCRIPTIVE INFERENCE PASS (CONDITIONAL)`; `PR REVIEW PENDING`; `CAUSAL VALIDITY NOT VERIFIED`.

## 7. Operational sequencing

1. **DONE:** Version contract on `feature/experiment-analysis-mart`, open Draft PR #6 and obtain owner approval.
2. **DONE:** Implement model, YAML/tests, and standalone source/QA queries in the same Draft PR.
3. **DONE:** Owner executed dbt build/test and BigQuery reconciliation; runtime/correctness evidence documented. Processing bytes and cost pending.
4. **DONE:** Reproduced the observed-group response rates and ratios from the built model (owner-executed).
5. **DONE:** Owner executed inferential query; all returned values agree with independent numerical reference. Interpreted as observational comparisons, not causal impact.
6. Review PR diff and merge only on explicit owner authorization. Minimal credential-free CI remains a **separate PR**; no CD in Session 05.

**Related references:** `docs/DECISIONS.md` (DEC-004, DEC-008, DEC-009, DEC-013), `docs/CUSTOMER_BEHAVIOR_SNAPSHOT_CONTRACTS.md`, `sql/qa/07_experiment_balance.sql`, `dbt/models/staging/stg_uplift_train.sql`, `dbt/models/marts/mart_customer_behavior_snapshot.sql`. Private Project Master v1.5 remains outside the public repository.
