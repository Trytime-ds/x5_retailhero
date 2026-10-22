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
