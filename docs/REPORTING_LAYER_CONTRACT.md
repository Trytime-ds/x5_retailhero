# Session 06 — Gate G reporting layer contract

**Status:** Independent BigQuery Gate G reporting reconciliation PASS (owner-provided on 2026-11-05). BigQuery view is queryable. CLI `dbt run` and `dbt test` logs NOT YET SHARED; full technical gate remains pending evidence.
**Handoff:** Power BI dashboard work is reserved for Session 07.
**Input:** `{{ ref('mart_experiment_analysis') }}`, 200,039 labeled clients,
observed historical behavioral context (not proven pre-SMS).

## Decision, consumers and scope

Publish an aggregated BigQuery reporting interface for source-defined
observed response analysis, leaving causal interpretation and all
dashboard implementation out of scope.

**Model:** `dbt/models/reporting/rpt_experiment_response_segments.sql`.
**Materialization:** `view` in the development dataset (`x5_dbt_dev`).
This is not a new independent fact table or a customer-level mart.
A view avoids storing duplicate customer-level data, is light to
maintain and is appropriate for a first BI import; it will re-query
the underlying mart on use, so measure actual bytes/costs after
deployment. No external publish/refresh action is authorized.

**Grain:** 1 row per `analysis_scope × segment`, with
a deterministic `analysis_key`. Exactly **16 rows** in current data:
- `overall`: 1 all-clients row
- `frequency`: 3 rows (Low <=8, Medium 9–18, High >=19)
- `recency`: 3 rows (Recent <=2, Intermediate 3–7, Less recent >=8)
- `joint`: 9 frequency×recency rows

**CRITICAL:** each of the four scopes represents the **same population**
from a different grouping. `SUM(clients)` across scopes artificially
quadruples the population. Only sum counts **within exactly one scope**.
Never average percentages, RR, RD, CI limits, or standardized rates.
Recompute the rate from appropriate `SUM(positive)/SUM(n)` counts
when aggregating legal, disjoint rows within a scope. `scope_order`
and `segment_order` provide stable UI sorting; frequencies and
recency labels are dimension attributes.

## Measures and meaning

- `clients`, `control_n`, `treatment_n`;
  `control_positive`, `control_negative`,
  `treatment_positive`, `treatment_negative`.
- `control_response_pct` and `treatment_response_pct` are numerical
  **percent 0–100**, not unit fractions.
- `observed_rd_pp` is 100*(treatment rate-control rate), in percentage
  points; `observed_rr` is the ratio of those two rates.
- `rd_ci95_lower_pp` / `rd_ci95_upper_pp` and RR log-Katz
  interval bounds are exploratory **unadjusted individual 95% CIs**
  only for `overall/frequency/recency` in supported data. For `joint`,
  they must be NULL; **no post hoc nine-cell CI/testing claims**.
  CI columns are not FDR-adjusted. Family A/B q values are documented
  in Session 06 analytical findings and are NOT inferred by this view.
- `pooled_std_control_response_pct`,
  `pooled_std_treatment_response_pct`, `pooled_std_rd_pp`,
  `pooled_std_rr` and `std_minus_raw_rd_pp`: common pooled
  joint-cell-weight descriptive standardization for the 7
  nonjoint scope rows. Set all to NULL for the 9 joint rows.
  These are **not estimated causal effects**.
- `support_status`: PASS_SUPPORT only for cells that meet source count
  consistency and each-arm n>=500, positive>=30, negative>=30.
  Invalid data marked STOP_INVALID_COUNTS; insufficient marked
  INSUFFICIENT_SUPPORT. No suppression of raw counts.
- `history_end_date` is a **historical observed cutoff**,
  **not** the SMS send date. `metric_semantics`,
  `causal_eligibility`, `inference_scope` and `ci_method`
  disambiguate dashboard presentation.

## Build and QA gates

1. Owner syncs feature branch and runs
   `dbt run --project-dir dbt --select rpt_experiment_response_segments`.
2. Owner executes
   `dbt test --project-dir dbt --select rpt_experiment_response_segments`
   (schema tests and a singular reconciliation test).
3. Independent BigQuery SQL
   `sql/qa/14_reporting_segments_reconciliation.sql` must show
   source 200,039/100,058/99,981 and positive/negative parity,
   all 16 predeclared keys and correct membership, 0 mismatches in
   exact ratios within tolerance, 9 null CI rows for joint,
   7 nonjoint rows with defined standardized values.
4. For **each scope separately**, totals of clients/control/treatment
   and outcomes must reconcile to the single labeled population.
   **Never** sum counts across all 16 view rows.
5. Confirm marginal and joint counts against owner-reported Gates
   B, E and F, including global original RD 3.3231 pp and global
   standardized RD 3.2112 pp, within stated rounding tolerance.
6. Capture actual execution evidence and BigQuery processed bytes
   if available. A published SQL/view file is NOT evidence it ran.
7. Keep PR #7 Draft until user reviews and authorizes merge.
   Keep Project Master private. CI/CD deployment remains out of scope.

## Gate G owner-reported independent BigQuery evidence — 2026-11-05

The owner executed `sql/qa/14_reporting_segments_reconciliation.sql`
on the reporting object in `x5_dbt_dev` and shared its two result
sets. **Each of the four alternative analytical scopes has
`PASS_RECONCILED`**:

| Scope | Expected / actual reporting rows | Clients | Control n | Treatment n | Control positive | Treatment positive |
|---|---|---:|---:|---:|---:|---:|
| overall | 1 / 1 | 200,039 | 100,058 | 99,981 | 60,363 | 63,639 |
| frequency | 3 / 3 | 200,039 | 100,058 | 99,981 | 60,363 | 63,639 |
| recency | 3 / 3 | 200,039 | 100,058 | 99,981 | 60,363 | 63,639 |
| joint | 9 / 9 | 200,039 | 100,058 | 99,981 | 60,363 | 63,639 |

The independent overall QA returned
`gate_g_status = PASS_RECONCILED`, with **4 scopes, 0 failing scopes,
16 expected keys, 16 actual rows, 16 distinct keys, 0 missing/mismatched
expected keys, 0 unexpected keys, 0 bad rate/count rows, 0 improper
joint inference/standardization rows, 0 missing nonjoint uncertainty/
standardization rows, 0 bad semantic/support flags, 200,039 distinct
source clients and 0 invalid source rows**. The expected
100,058/99,981 treatment/control counts are unchanged.

**Interpretation:** the reporting relation is queryable and the
separate BigQuery reconciliation passes. The supplied results are
evidence of **warehouse-side output validity**, not a transcript of the
dbt build or its schema/singular tests. No `dbt run`/`dbt test` output
was supplied. **Do not mark Gate G technical build/test COMPLETE until
the CLI run and tests are supplied and reviewed.** Actual BigQuery
bytes processed, elapsed time and costs not yet supplied. No GitHub
Actions CI has been run/claimed.

This independent check is particularly important because, across the
four scopes, an erroneous total `SUM(clients)` would be **800,156**,
not the true 200,039 unique source customers. The `analysis_scope`
field is mandatory for correct Power BI filter context in Session 07.

## Explicit exclusions

Power BI visuals, DAX, relationship design, custom dashboard filters,
API/services, training `uplift_test`, RFM monetary fields, target
attribution windows, uplift predictions, ROI, causal SMS business
decisions and targeting deployment are excluded.

**Important:** randomized assignment, T0, actual exposure and outcome
observation window are unverified. Descriptive statistics do not
identify incremental purchases due to SMS.
