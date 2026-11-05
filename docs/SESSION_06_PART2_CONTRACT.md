# Session 06 — Part 2 analytical and reporting contract

**Status:** Gate E owner-executed PASS on 2026-11-05; Gate F SQL published NOT RUN; Gate G reporting NOT STARTED. Approved session scope by owner:
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

Choose an appropriate BigQuery `VIEW` or dbt `reporting` layer after
Gate E/F review and explain the cost/performance tradeoff. A new dbt
materialization requires contract/test/evidence and an explicit review;
no blind deployment to BigQuery.

**Reporting QA:** expected 16 total rows (1 overall+3+3+9);
reconcile *each scope separately* to 200,039 clients / 100,058
controls / 99,981 treatment and 60,363 / 63,639 positive outcomes,
while ensuring source overall population is never added 4 times.
Validate recomputed ratios from raw counts, null-safe treatment of
zero denominators and compatibility with future Power BI consumption.

## Documentation and approval

- Gate E/F/G should each be documented with source output, SQL, QA results,
  observed limitations and actual bytes processed if supplied.
- Update `docs/SEGMENT_HETEROGENEITY_CONTRACTS.md`, analytical findings,
  README, CHANGELOG and DECISIONS *after verified evidence*.
- Keep Project Master private and PR #7 Draft until diff review and
  explicit owner authorization for merge.
- **Session 07:** Power BI model, measures, visualizations and dashboard.
- No causal SMS uplift, ROI, revenue, or deployment-ready targeting.
