# Session 06 — Part 2 analytical and reporting contract

**Status:** Gates E, F and G owner-executed PASS on 2026-11-05. Gate G evidence: dbt view run 1/1 PASS, dbt tests 28/28 PASS, BigQuery independent QA 4/4 scopes PASS; PR #7 remains Draft. Approved session scope by owner:
joint frequency×recency analysis → robustness/sensitivity → reporting layer →
documentation and review; **Power BI dashboard deferred to Session 07**.
Existing Gates A–D passed on owner-executed BigQuery 2026-11-05; PR #7 stays Draft.

## Gate E — joint 3×3 descriptive response analysis

**Question:** How do observed source-defined treatment/control response contrasts
vary jointly across fixed ticket frequency and historical recency groups?
Does stratification alter the marginal interpretations from Gate C?

**Grain:** one labeled training client per source `mart_experiment_analysis`,
assigned exactly one joint cell. The resulting analytical **grain is one
frequency segment × one recency segment × source arm**, then pivot to one
row per joint segment for contrasting the arms. Do **not** mix this with
the two independent marginal analyses by adding populations across them.

**Frozen dimensions, NO outcome-driven changes:**
- Frequency Low <=8, Medium 9–18, High >=19 tickets in historical 90d.
- Recency Recent <=2, Intermediate 3–7, Less recent >=8 days since last
  observed purchase at the 2019-03-18 history end (NOT verified SMS T0).
- The complete 3×3 expected joint membership/control/treatment cell
  counts were obtained **without outcome** in owner-run Gate D and are frozen.
- Predeclared total count/support for nine joint cells; prefer counts/rates
  over row-level visualization to protect privacy and avoid overclaiming.

**Measures:** counts n and positives/negatives for each arm; observed
response rates, risk difference (RD, treatment−control, pp) and risk ratio
(RR); always recompute rates from numerator and denominator, never
average percentages. Sufficient cell support uses the same declared
threshold as Gate B: each arm n>=500 AND at least 30 positives and 30
negatives. Cells failing support remain visible with an explicit
`INSUFFICIENT_SUPPORT` flag and no inferential claims.

**QA:**
1. 200,039 unique train clients; exactly 9 nonempty cross-cells with
   complete joint assignment and no invalid treatment/target labels.
2. Reproduce **all nine Gate D memberships**, including each cell's
   control and treatment counts. Stop on source drift.
3. Reconcile global arm counts/target totals against the independent
   source `stg_uplift_train` and against Gate B's 100,058 controls,
   99,981 treatments, positives 60,363 / 63,639.
4. Reconcile all six *marginal* (segment×arm) counts and positives
   against Gate B independently for frequency and recency.
5. If Gate E QA passes, freeze the results and record owner-run query
   evidence, without interpreting individual cells as causal effects.

**Statistical boundary:** exploratory cross-cell descriptive RD/RR only.
**No new unplanned pairwise significance tests, no ranking of "best SMS
targets" based on p-values and no extrapolation to uplift.** The 9-cell
analysis is post hoc relative to the prespecified Gate C family.
Global and marginal differences are not generally simple averages of
segment RDs; arm composition matters.

### Gate E owner-executed evidence — 2026-11-05

Owner executed `sql/analysis/08_joint_segment_observed_response.sql` in BigQuery
US and provided both result sets. All **9/9 joint cells PASS_SUPPORT** and
`gate_e_status = PASS_RECONCILED`, with **0** joint membership mismatches,
**0** below-support cells, **0** marginal mismatches across six original
Gate B segments, **0** invalid source records and **0** source-to-mart
field mismatches. The cross-cells reconcile to **200,039** clients,
**100,058** control (60,363 positive / 39,695 negative), **99,981**
treatment (63,639 positive / 36,342 negative).

| Frequency | Recency | N | Control n/positive | Treatment n/positive | Control response % | Treatment response % | Observed RD pp | RR |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Low | Recent | 9,944 | 5,001 / 2,539 | 4,943 / 2,728 | 50.7698 | 55.1892 | +4.4193 | 1.087046 |
| Low | Intermediate | 20,753 | 10,374 / 4,050 | 10,379 / 4,557 | 39.0399 | 43.9060 | +4.8661 | 1.124643 |
| Low | Less recent | 39,247 | 19,721 / 5,970 | 19,526 / 6,781 | 30.2723 | 34.7281 | +4.4558 | 1.147189 |
| Medium | Recent | 25,301 | 12,718 / 8,916 | 12,583 / 9,264 | 70.1054 | 73.6231 | +3.5178 | 1.050178 |
| Medium | Intermediate | 23,426 | 11,780 / 7,537 | 11,646 / 7,835 | 63.9813 | 67.2763 | +3.2950 | 1.051499 |
| Medium | Less recent | 19,590 | 9,783 / 5,148 | 9,807 / 5,454 | 52.6219 | 55.6133 | +2.9914 | 1.056848 |
| High | Recent | 40,820 | 20,322 / 18,296 | 20,498 / 18,717 | 90.0305 | 91.3113 | +1.2808 | 1.014227 |
| High | Intermediate | 15,025 | 7,470 / 6,121 | 7,555 / 6,328 | 81.9411 | 83.7591 | +1.8180 | 1.022187 |
| High | Less recent | 5,933 | 2,889 / 1,786 | 3,044 / 1,975 | 61.8207 | 64.8817 | +3.0610 | 1.049515 |

**Gate E decision: PASS for structural and descriptive reconciliation.**
The nine source-defined RD differences are descriptive only; no new
joint-cell hypothesis tests or individualized treatment effects are
authorized. Low-frequency RDs are relatively stable across recency,
while the high-frequency segment shows a larger observed RD among
less-recent customers than among recent customers. Strong baseline
gradients and response ceilings require further challenge before
business conclusions.

## Gate F — robust, outcome-scale and composition challenge

After Gate E evidence is reviewed:
- Assess *absolute vs relative scales* (RD and RR) and treatment/control
  baseline response differences. Document high-response ceiling effects.
- Compare joint-cell patterns with original frequency/recency marginal
  results. Explicitly identify possible Simpson/composition effects.
- **Predefined descriptive composition standardization:** execute
  `sql/analysis/09_joint_composition_standardization.sql` to compute
  raw and common-weight pooled-cell response/RD/RR for seven alternative
  reporting cuts (overall + three frequency + three recency). Apply the
  SAME pooled joint-cell weights to both arms within each cut. Compare
  absolute vs relative contrasts and inspect the nine-cell mechanical
  response ceilings. This is an arithmetic sensitivity check, NOT causal
  confounding correction, inferential test or independent replication.
  Run the entire script and review all **three** result sets, including
  the independent `gate_f_status` reconciliation.
- **No new significance testing of joint cells** and no unplanned
  recutting of frequency/recency thresholds.

### Gate F execution evidence — owner-reported 2026-11-05

Owner executed `sql/analysis/09_joint_composition_standardization.sql`
in BigQuery US and provided **all three result sets**. The user-reported
`gate_f_status=PASS_RECONCILED`; `scopes=3`, `summary_rows=7`,
and **zero** bad scope group counts, bad scope reconciliations, bad
pooled weights or raw marginal mismatches. Assistant independently
recomputed raw and pooled-weight RDs from Gate E integer counts
and reproduced every change to displayed precision. No assistant
warehouse execution or GitHub Actions run occurred.

| Scope | Segment | Raw observed RD pp | Pooled-cell-standardized RD pp | Change pp |
|---|---|---:|---:|---:|
| Overall | All clients | 3.3231 | 3.2112 | -0.1119 |
| Frequency | Low | 4.5792 | 4.5723 | -0.0068 |
| Frequency | Medium | 3.2506 | 3.2905 | +0.0398 |
| Frequency | High | 1.4848 | 1.5824 | +0.0977 |
| Recency | Recent | 2.5544 | 2.4352 | -0.1192 |
| Recency | Intermediate | 3.5101 | 3.4709 | -0.0393 |
| Recency | Less recent | 4.0534 | 3.8851 | -0.1683 |

All standardized differences retain the sign and general order of
their raw observed counterparts. The global difference shifts
-0.1119 pp; this is a **small observed composition sensitivity**
under this specific common-weight standardization, not evidence
that unmeasured confounding or selection is small.

**Ceiling/scale diagnostic (9 joint cells, owner-reported):**
- High frequency + Recent: control response **90.0305%**,
  observed RD **+1.2808 pp**, RR **1.014227**; mathematical upward
  headroom from control is only **9.9695 pp**.
- Low frequency + Less recent: control response **30.2723%**,
  RD **+4.4558 pp**, RR **1.147189**; headroom **69.7277 pp**.
- Distinct raw RD and RR patterns can be influenced by the
  bounded binary response scale and baseline risk; headroom is
  a mathematical ceiling, **not** expected SMS incrementality.
- No joint-cell inferential tests were conducted and none are
  implied by this sensitivity analysis.

**Gate F: PASS for verified arithmetic reconciliation and sensitivity
diagnostics.** Does not establish randomized assignment, target
causality, pre-SMS timing, or generalizability.

## Gate G — data product for reporting (no dashboard work)

Deliver a reproducible and inspectable aggregate data contract with at
least the source dimensions, outcome counts/denominators and rate/contrast
fields, so that any reporting tool **never averages rates or double-counts
clients between two marginal dimensions and the joint analysis**.

**Preferred shape:** explicitly tagged `analysis_scope` for:
- `overall`: one total row with source control and treatment counts.
- `frequency`: three frequency segment rows.
- `recency`: three recency segment rows.
- `joint`: nine frequency × recency rows.
Two marginal cuts and the joint cut are **alternative views of the
same 200,039 clients**, never additive. Supply `sort_order`, explicit
`metric_semantics`, numerator/denominator, `observed_rd_pp`,
`observed_rr`, eligibility/support and QA flags. Avoid label fields
that imply verified uplift or economic contribution. Do not embed
historical experimental results as static hardcoded reporting data.

**Design built and validated 2026-11-05:** `dbt/models/reporting/rpt_experiment_response_segments.sql` is a BigQuery **view**, with schema contract `dbt/models/reporting/_reporting.yml`, singular source-count and scope reconciliation test `dbt/tests/assert_reporting_response_scope_reconciliation.sql`, and independent BigQuery QA `sql/qa/14_reporting_segments_reconciliation.sql`. See `docs/REPORTING_LAYER_CONTRACT.md` for grain, measures and null inferential fields in joint scope. A view avoids storing a duplicate customer table but recomputes aggregations when queried; resource usage is unreported. **Owner-reported dbt run 1/1 PASS, dbt test 28/28 PASS and independent BigQuery QA 4/4 PASS.**

**Reporting QA:** expected 16 total rows (1 overall+3+3+9);
reconcile *each scope separately* to 200,039 clients / 100,058
controls / 99,981 treatment and 60,363 / 63,639 positive outcomes,
while ensuring source overall population is never added 4 times.
Validate recomputed ratios from raw counts, null-safe treatment of
zero denominators and compatibility with future Power BI consumption.

### Gate G independent BigQuery QA evidence — 2026-11-05

Owner ran `sql/qa/14_reporting_segments_reconciliation.sql` against
the reporting object and shared both result sets. **4/4 scopes
`PASS_RECONCILED`**, each reproducing 200,039 labeled clients,
100,058 control, 99,981 treatment, 60,363 control positive and
63,639 treatment positive. The overall `gate_g_status` is
`PASS_RECONCILED` with **16 rows / 16 distinct keys**, zero
mismatched/extra/missing keys, zero incorrect rates/counts, zero
improper confidence intervals or standardized measures in the
nine post-hoc joint rows, zero missing allowed nonjoint measures,
zero semantic/support errors and zero invalid source rows.

**Subsequent owner-supplied CLI evidence (2026-11-05):** the dbt
reporting **view ran 1/1 PASS** in **13.95 seconds**, with
`WARN=0, ERROR=0`. The selected test suite completed **28/28 PASS**
in **29.70 seconds**, also `WARN=0, ERROR=0`. Together with
independent warehouse reconciliation, **Gate G is technically PASS**.
These results were owner-executed, not CI. View bytes scanned and
processing cost remain unreported.

The four scopes are four alternative cuts of the **same** customers,
not four independent populations. Power BI remains the work of
Session 07.

## Documentation and approval

- Gate E/F/G should each be documented with source output, SQL, QA results,
  observed limitations and actual bytes processed if supplied.
- Update `docs/SEGMENT_HETEROGENEITY_CONTRACTS.md`, analytical findings,
  README, CHANGELOG and DECISIONS *after verified evidence*.
- Keep Project Master private and PR #7 Draft until diff review and
  explicit owner authorization for merge.
- **Session 07:** Power BI model, measures, visualizations and dashboard.
- No causal SMS uplift, ROI, revenue, or deployment-ready targeting.
