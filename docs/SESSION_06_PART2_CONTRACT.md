# Session 06 — Part 2 analytical and reporting contract

**Status:** PROPOSED / Gate E SQL NOT RUN. Approved session scope by owner:
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

## Gate F — robust, outcome-scale and composition challenge

After Gate E evidence is reviewed:
- Assess *absolute vs relative scales* (RD and RR) and treatment/control
  baseline response differences. Document high-response ceiling effects.
- Compare joint-cell patterns with original frequency/recency marginal
  results. Explicitly identify possible Simpson/composition effects.
- Optional **prespecified analysis of composition:** calculate descriptive
  within-frequency and within-recency standardized response differences
  using a **common pooled joint-cell distribution**, applied to both
  source arms. Do not treat standardization as identifying causal impact;
  report both original and composition-standardized contrasts with
  unadjusted sensitivity interpretation.
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
