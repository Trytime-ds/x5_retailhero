# Technical Decisions

## DEC-001 — RAW data preservation
Store source columns as STRING in BigQuery RAW.
Type conversion and standardization belong to staging.

## DEC-002 — Purchase granularity
A purchase row represents a product line.
The composite key is:
(client_id, transaction_id, product_id).

## DEC-003 — Transaction amounts
purchase_sum is constant within each transaction group.
Do not aggregate it directly across product lines.
Validate ticket-level monetary semantics before modeling.

## DEC-004 — Experiment structure
uplift_train and uplift_test contain distinct clients
and jointly cover the clients source.

Structural integrity does not establish randomization
or causal validity.

## DEC-005 — Source keys and relationships (Session 02)
products.product_id has 43,038 non-null, non-empty, distinct values
across 43,038 source rows. Joining purchases to clients and products
preserves all 45,786,568 purchase lines; both orphan counts are zero.
This passes structural referential-integrity checks, not business-field QA.

## DEC-006 — Purchase quantity anomalies
2,707,278 purchase lines (5.91%) have quantity=0. No missing,
nonnumeric or negative quantities were observed.
The investigated vendor has a 27.07% zero-quantity rate versus
2.50% for other vendors; within one level_1/level_2 category,
the corresponding comparison is 27.07% versus 14.10%.
This is a conditional association, NOT proof of a promotion mechanic.
Three product lines exceed 1,000 in quantity: two transactions,
two clients. Maximum observed quantity is 14,941.
Preserve RAW; do not remove, impute or cap values automatically.
Stage a typed quantity and a zero-quantity indicator; quantity units
and suitability for sum-of-units features remain unverified.

## DEC-007 — Client demographics and loyalty QA
Preserve all 400,162 clients. Age anomalies: 96 negative, 42 zero,
5,414 aged 1–17, 1,049 over 100. These diagnostic thresholds
are not grounds for deleting customers; flag questionable age values.
35,469 first-redemption dates are missing, not malformed.
536 first-redemption dates precede issue dates. Keep source values
and expose explicit chronology/missingness flags.
The meaning of the U gender category is not formally verified.

## DEC-008 — Historical cutoff and leakage boundary
Purchases span 2018-11-21 21:02:33 through 2019-03-18 23:40:03,
with purchases on 118 distinct dates. 44,953 clients have first
redemptions AFTER 2019-03-18. The 2019-03-18 date is the OBSERVED
purchase-history end, NOT an established SMS sending time (T0).
Purchases are documented as precommunication, but treatment timestamp
and target outcome window remain unknown. Never use information
that would be post-treatment in a pre-treatment customer feature.

## DEC-009 — Observed balance does not prove randomization
Demographic distributions (gender F/M/U) are similar across arms.
Treatment/control mean historical transaction counts: 20.19/20.06;
mean recency: 5.83/5.83 days measured at purchase-history end.
SMD(transaction count)=+0.0073; SMD(recency)=-0.0002.
These are strong descriptive balance diagnostics for two covariates,
NOT evidence of the assignment mechanism or balance on all confounders.
Observed conversion difference +3.3231 percentage points is
DESCRIPTIVE, not an established causal effect of SMS.

## DEC-010 — Session 02 gates and next layer
Source-key and referential integrity: PASS structurally.
Targeted DQ: profiling complete with limitations; broader DQ remains open.
Experiment causal validity: NOT VERIFIED (assignment/T0/outcome unknown).
Temporal/leakage: PARTIAL (loyalty data outlast purchase history).
Monetary semantics of purchase_sum are still unverified.
Proceed to dbt sources/staging with explicit types and flags;
continue withholding causal and SMS economic claims.


## DEC-011 — Transaction-level intermediate model (Session 04)
One row per `(client_id, transaction_id)` in `int_transactions`.
Ticket-level `store_id`, `transaction_datetime` and `purchase_sum`
were found consistent across lines: zero inconsistent tickets across
8,045,229 tickets. Aggregate validation on 2026-10-22 reconciled
45,786,568 original lines, 2,707,278 zero-quantity lines and three
extreme-quantity lines, all six QA checks TRUE, and 10/10 dbt tests PASS.
Materialize as a BigQuery date-partitioned, client-clustered table.
Retain `purchase_sum_reported` exactly once per transaction, but
**do not call it validated revenue**; no SMS incremental revenue,
ROI or causality claims are supported. Preserve anomaly line counts,
not unvalidated quantity units. PASS is limited to the transaction
model gate; the PR merge is a separate approval.

## DEC-012 — Customer-level observed purchase history (Session 04)
`int_customer_purchase_history` uses `stg_clients` as the customer
universe, left-joining aggregated, validated `int_transactions`.
All 400,162 clients currently have observed transactions, so no-purchase
fallback behavior (0 activity and NULL purchase dates/recency) is
not exercised by the present data; retain it to protect future coverage.
Recency is computed at the global last observed purchase date
(2019-03-18), **not** the unverified intervention time T0.
Use only historical ticket/day/store/line counts and dates, excluding
unverified monetary, loyalty and experiment-specific fields.
User-executed `dbt run` 1/1 PASS, `dbt test` 8/8 PASS; BigQuery QA
8/8 TRUE: 400,162 clients, 8,045,229 tickets and 45,786,568 lines
reconciled with zero/extreme anomalies preserved. This technical
PASS does not establish causal, economic, or treatment-time validity.
PR #4 merged into main as commit `83566a0`.

## DEC-013 — Descriptive 30/60/90-day customer snapshot mart (Session 04)
The first mart retains one row per client (400,162 source clients)
and reports ticket counts and active days over nested, inclusive trailing
calendar windows: 30d offsets 0..29, 60d offsets 0..59, and 90d
offsets 0..89. All dates are anchored at the final observed
purchase-history day (2019-03-18), **not** established SMS T0.
Preserve total historical frequency and recency from the validated
Intermediate customer entity; avoid unverified monetary and loyalty
semantics, unit quantities, treatment/outcomes and arbitrary segments.
User-executed dbt run 1/1 PASS, dbt test 9/9 PASS; BigQuery QA
9/9 TRUE. Window source/mart tickets: 2,444,257 (30d),
4,534,601 (60d), 6,393,058 (90d), and 36,583,505
product lines in 90d. No invalid nested-window rows observed.
This is a descriptive behavioral mart only: causal and treatment-time
validity gates remain open. PR #5 merged on 2026-10-22 as commit `435e96a`.


## DEC-014 — Observed experiment response analysis mart (Session 05 design)
The owner approved the Session 05 contract on 2026-11-02. The owner-approved
`mart_experiment_analysis` takes `stg_uplift_train` (200,039 clients)
as its only labeled experimental universe, with **one row per client**
and original binary `treatment_flg` and `target`. `stg_uplift_test`
(200,123 unlabeled, disjoint customers) is excluded. A LEFT JOIN to
`mart_customer_behavior_snapshot` supplies **descriptive historical
context only**, never certified pre-treatment features. Rates are
calculated within each source-defined arm, with group denominators;
RD and RR are observed contrasts rather than causal estimands.
On 2026-11-02, owner-executed pre-build BigQuery QA found source
population = unique clients = 200,039, with 0 invalid arm/outcome
values. The left join preserved all 100,058 control and 99,981
treatment clients, 0 unmatched, 0 invalid observed anchors;
response rates were 60.3280% and 63.6511% (difference +3.3231 pp).
Post-build owner-reported evidence (2026-11-02): dbt model run **1/1 PASS**
in 15.55 s; tests **17/17 PASS** in 20.77 s, with 0 warnings/errors.
Independent BigQuery reconciliation reproduced both groups and all
source outcomes (control: 100,058/60,363; treatment: 99,981/63,639),
with 0 missing clients, 0 experimental/behavioral field mismatches,
0 missing behavior matches, 0 invalid historical anchors, and
**16/16 TRUE** flags across two arms. This validates structural/semantic
parity within the modeled fields; it does NOT prove experiment
randomization, outcome timing, or SMS causality. Owner-reported inferential BigQuery SQL (2026-11-02) independently
reproduced: observed RD +3.3231 percentage points with approximate 95%
CI [+2.8979, +3.7483] pp; observed RR 1.055084 with approximate 95%
CI [1.047861, 1.062356]; pooled two-sided z=15.3093 and
p < 1e-10. All three inferential boolean checks passed.
These statistics depend on independent-binomial and large-sample
assumptions; small p-values and confidence intervals do NOT establish
causal SMS incrementality. Resource bytes/charges remain unreported,
and PR #6 was subsequently squash-merged to main on 2026-11-02
(Chile time) as commit `6210d9c`. Monetary, causal and targeting-deployment
claims remain out of scope.

## DEC-015 — Outcome-blind descriptive segmentation and conditional heterogeneity (Session 06)

Owner approved *two separate descriptive dimensions* before analyzing
segment outcomes: `transactions_90d` (frequency) and
`recency_days_at_history_end` (recency). Exact pooled discrete tertiles
on the 200,039 labeled train clients produced frozen frequency cutoffs
8/18 and recency 2/7. Boundaries are never retuned using target.
Six segments cover the full labeled train set independently by dimension.

Gate A (distribution), Gate B (response / source reconciliation),
Gate C (six within-segment comparisons and four prespecified RD
heterogeneity contrasts with 95% intervals and BH-FDR), and Gate D
(outcome-blind companion-feature SMD / 9-cell overlap diagnostic)
were executed by the project owner in BigQuery US on 2026-11-05.
Reported Gate B supports: 6/6 `PASS_SUPPORT`, 2/2
`PASS_RECONCILED`; Gate C arithmetic matches independent reference.
Observed frequency Low/Medium/High RDs: +4.5792 / +3.2506 / +1.4848
pp; recency Recent/Intermediate/Less recent: +2.5544 / +3.5101 /
+4.0534 pp. Three of four BH-adjusted *descriptive* differences
in RDs meet q<0.05; the intermediate-vs-recent comparison does not.
Gate D: maximum absolute companion SMD 0.010189; the nine
frequency×recency cells reconcile all 200,039 clients, with
max absolute arm composition delta 0.1917 pp. The two segment
dimensions overlap substantially and are not additive opportunities.

Interpretation: customer historical activity is associated with binary
target rates and observed treatment/control contrasts. This cannot
identify causal SMS effectiveness or individual uplift: source
randomization, exposure, intervention timing, target outcome window
and certified pre-SMS feature eligibility are still NOT VERIFIED.
The high-frequency arm's high baseline response also means absolute
risk differences may be constrained by ceiling effects. Small SMD
values do not prove exchangeability. The exploratory FDR results are
not confirmatory due to assumptions and reuse of customers across
dimensions. Recommendation is to formulate and prospectively test
hypotheses in an auditable randomized CRM experiment; **no rollout**.

No new dbt model, warehouse CI, incremental revenue or ROI computation.
Queries and owner-reported results are versioned in
`docs/SEGMENT_HETEROGENEITY_CONTRACTS.md` and
`docs/SESSION_06_ANALYTICAL_FINDINGS.md`; PR #7 remains Draft
until explicit owner review/approval.

## DEC-016 — Joint descriptive response and BI reporting scopes (Session 06 Part 2)

Continue the approved noncausal exploratory analysis without altering
frequency (<=8 / 9–18 / >=19) or recency (<=2 / 3–7 / >=8) cutoffs.
Gate E: a **post-hoc nine-cell** frequency×recency response table,
all cells PASS_SUPPORT, with exact reconciliation against both
original arm-positive counts and the six frozen Gate B marginal rows.
No additional joint-cell significance tests, selection of winners
or claims of causal heterogeneity.

Gate F: common-weight pooled joint-cell standardization for
seven scopes (overall+3 frequency+3 recency) uses one identical
within-scope distribution for both source-defined arms. Owner-run
BigQuery QA `PASS_RECONCILED`; raw global observed RD +3.3231 pp
vs standardized +3.2112 pp, change −0.1119 pp. This limited
compositional sensitivity, plus absolute-vs-relative and high baseline
headroom diagnostics, **does not** certify pre-treatment validity,
identify SMS causal effects, remove unobserved confounding, or justify
targeting rollout. Original and standardized metrics must be labeled
as observational.

Gate G **reporting model choice**: use a dbt-managed BigQuery `view`
rather than another customer-level table, aggregating the existing
`mart_experiment_analysis`. The view has **16 rows** with explicit
alternative `analysis_scope`: 1 overall, 3 frequency, 3 recency,
9 joint. Each scope holds *all 200,039 clients* in mutually exclusive
segments *within that scope*, and **counts must never be summed across
scopes**. Raw numerator/denominator counts remain inspectable.
Rates and RD/RR are derived, not summable; recompute them from count
totals when aggregating. Common-weight standardized values and
non-FDR-adjusted CI limits are available only for nonjoint rows.
Joint-cell inference/CI values must be null, with explicit semantic
flags prohibiting causal interpretation.

Owner-reported independent BigQuery QA (2026-11-05),
`sql/qa/14_reporting_segments_reconciliation.sql`, gave
**4/4 `PASS_RECONCILED` scopes**, 16/16 distinct keys and
0 missing/mismatched/unexpected keys, count/rate errors, incorrect
joint CI/standardized measures, missing nonjoint measures, semantic
or support errors. It reconciles 200,039 unique source clients,
100,058 control and 99,981 treatment with original outcomes.
**dbt build/test CLI logs not yet supplied**; independent BigQuery
QA PASS must not be mislabeled as completed dbt model/test validation.

Future Power BI must filter to one scope at a time and treat
derived rates/intervals as nonadditive. Power BI/dashboard postponed
to Session 07 by the owner. PR #7 stays Draft, no merge until explicit
review and authorization. The Project Master remains private.
