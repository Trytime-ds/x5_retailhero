# Session 06 — Descriptive Response Heterogeneity Contract

**Status:** Design APPROVED and empirical cutoffs FROZEN from owner-executed BigQuery Gate A on 2026-11-05. Gate A distribution PASS (both dimensions); no Session 06 response or inference queries have been executed.
**Scope:** Outcome-blind segment design first; descriptive treatment/control response comparisons second.
**Base:** `mart_experiment_analysis` in BigQuery `x5_dbt_dev`; one row per 200,039 distinct `stg_uplift_train` clients.
**History anchor:** 2019-03-18, observed purchase-history end. **NOT** independently verified SMS T0.

## 1. Business question and limits

How do *observed* binary response rates, and the between-arm observed differences, vary across customer profiles defined by purchase activity?

This is exploratory descriptive heterogeneity, **not** verified conditional average treatment effects, incremental purchases from SMS, targeting uplift, or deployment authorization. Randomization, SMS delivery/exposure, intervention T0, and the target outcome window have not been independently established. Historical behavior is **not certified as pre-treatment**.

## 2. Source contract and analysis population

- Source: `{{ ref('mart_experiment_analysis') }}`. Preserve all labeled train clients with `client_id`, `treatment_flg` (0/1), and `target` (0/1).
- Exclude `stg_uplift_test`: treatment and target are unavailable.
- Dimension A (frequency): `transactions_90d`, historical ticket count over inclusive 90-calendar-day window ending at observed cutoff.
- Dimension B (recency): `recency_days_at_history_end`, days since last observed ticket at cutoff; lower means more recent.
- No revenue, quantity-unit aggregates, loyalty timestamps, demographic anomalies, or post-treatment-derived features.
- Each dimension is analyzed *separately*. Do not cross dimensions or infer individualized uplift.
- Keep missing recency as a named **Missing** group rather than dropping it. Non-null frequency is expected by upstream contract; unexpected missing frequency is a QA failure, not implicit zero.

## 3. Segment construction — freeze before looking at outcomes

For **each dimension separately**, derive exact empirical 33rd and 67th percentile cutoffs (`PERCENTILE_DISC` at 1/3 and 2/3, using BigQuery Standard SQL) **from all 200,039 train clients pooled**, never stratified by treatment or target. Ignore missing observations for computing recency cutoffs, but retain them as a separate Missing segment.

- Frequency: **Low** `x <= q33`; **Medium** `q33 < x <= q67`; **High** `x > q67`.
- Recency: **Recent** `x <= q33`; **Intermediate** `q33 < x <= q67`; **Less recent** `x > q67`. Missing stays separate.
- Preserve ties: all customers with the same value belong to the same segment. Percentiles are *cutoff values*, not a guarantee of equal group sizes.
- If `q33 >= q67`, segment boundaries collapse. **STOP / request a revised threshold contract before outcome-based segmentation**; do not quietly switch to arbitrary thresholds or select cutoffs based on observed effects.
- Record cutoff values, percentile method, distribution counts, missingness, observed source data version/cutoff, and any zero-value concentration as reproducibility evidence.
- No segment may be selected, excluded, or redefined using `target`, observed treatment/control difference, confidence intervals, or p-values.

### Pre-outcome gate A (required)

Create and execute a **distribution-only** BigQuery query showing for each dimension: min/p33/median/p67/max, missing count, number of distinct values, zero count, cutoff-tie frequencies, and final segment counts **without any treatment or outcome columns**. Check exactly 200,039 assigned clients per dimension, no duplication and no loss. Owner must review/freeze cutoff values *before* the segment response query is written/executed. **Completed 2026-11-05: cutoffs frozen from the reported Gate A results below.**

### Gate A execution evidence — owner-reported 2026-11-05

Executed `sql/analysis/04_segment_distribution_precheck.sql` in BigQuery; owner supplied both result sets. **No direct warehouse execution by assistant or GitHub Actions.** Both dimensions returned `PASS_READY_FOR_CUTOFF_REVIEW`; the subsequent review found no collapsed percentiles, missing feature values, negative feature values, duplicates or lost clients.

| Dimension | Rows / unique clients | Missing / negative | Zero | Distinct values | Range | p33 / median / p67 | Ties at p33 / p67 |
|---|---:|---:|---:|---:|---:|---|---:|
| `frequency_90d` | 200,039 / 200,039 | 0 / 0 | 0 | 171 | 1–282 | **8 / 12 / 18** | 9,387 / 4,979 |
| `recency_days` | 200,039 / 200,039 | 0 / 0 | 35,273 | 23 | 0–22 | **2 / 4 / 7** | 18,614 / 10,699 |

**Frozen bins (do not tune on outcomes):**

| Dimension | Segment | Rule | Owner-observed clients | Share |
|---|---|---|---:|---:|
| `frequency_90d` | Low | 1–8 tickets (`x <= 8`) | 69,944 | 34.97% |
| `frequency_90d` | Medium | 9–18 tickets (`8 < x <= 18`) | 68,317 | 34.15% |
| `frequency_90d` | High | 19+ tickets (`x > 18`; observed max 282) | 61,778 | 30.88% |
| `recency_days` | Recent | 0–2 days (`x <= 2`) | 76,065 | 38.03% |
| `recency_days` | Intermediate | 3–7 days (`2 < x <= 7`) | 59,204 | 29.60% |
| `recency_days` | Less recent | 8+ days (`x > 7`; observed max 22) | 64,770 | 32.38% |

**Reconciliation:** frequency 69,944 + 68,317 + 61,778 = **200,039**; recency 76,065 + 59,204 + 64,770 = **200,039**. Rounded shares may not sum exactly to 100%. The large recency-zero concentration (35,273, ~17.63% of train) and boundary ties are documented. Bins are comparable descriptively, not guaranteed equal size or pre-SMS. The frozen rules require versioned data-change review before application to a refreshed source; future values outside currently observed minima/maxima are still classified by the inequality rules.

**Gate A status: PASS — cutoffs and membership counts frozen.** No outcome-bearing query was run to select thresholds. The later per-arm support gate is **PENDING**.

## 4. Minimum cell support and QA

Once boundaries are frozen, calculate by dimension × segment × arm:
- `n_clients = COUNT(*)` (unique customer grain), `positive = COUNTIF(target=1)`, `negative = COUNTIF(target=0)`, `response_rate = positive / n_clients`.
- Preserve the original control and treatment totals across the segments for **each** dimension; group contributions must reconcile to 100,058 control, 99,981 treatment, 60,363 control positives, and 63,639 treatment positives.
- Inferential reporting eligibility requires **n >= 500 in each arm AND >= 30 positives and >= 30 negatives per arm**. These thresholds are conservative *analysis safeguards*, not proof of normality or unbiased sampling.
- For insufficient cells: show counts descriptively, flag `INSUFFICIENT_SUPPORT`, and **suppress inferential claims** rather than dropping customers or changing boundaries in response to outcomes.
- Do not interpret numerical rates for `n=0`; use NULL and explicit status.
- Unexpected treatment/target values, duplicated client IDs, missing source rows or misclassified boundaries are QA failures.

### Gate B executed evidence — owner-reported 2026-11-05

Owner executed `sql/analysis/05_segment_observed_response.sql` on frozen bins and supplied both result sets. Both dimensions returned `PASS_RECONCILED`; **6/6 segments `PASS_SUPPORT`**. These are **observed**, not causal, response differences. The assistant independently recomputed rates and contrasts from the supplied integer arm counts; no direct warehouse or CI execution was performed.

| Dimension | Segment | Control n / positive | Treatment n / positive | Control rate | Treatment rate | Observed RD (pp) | RR |
|---|---|---:|---:|---:|---:|---:|---:|
| Frequency | Low | 35,096 / 12,559 | 34,848 / 14,066 | 35.7847% | 40.3639% | +4.5792 | 1.127964 |
| Frequency | Medium | 34,281 / 21,601 | 34,036 / 22,553 | 63.0116% | 66.2622% | +3.2506 | 1.051588 |
| Frequency | High | 30,681 / 26,203 | 31,097 / 27,020 | 85.4046% | 86.8894% | +1.4848 | 1.017385 |
| Recency | Recent | 38,041 / 29,751 | 38,024 / 30,709 | 78.2077% | 80.7622% | +2.5544 | 1.032662 |
| Recency | Intermediate | 29,624 / 17,708 | 29,580 / 18,720 | 59.7759% | 63.2860% | +3.5101 | 1.058722 |
| Recency | Less recent | 32,393 / 12,904 | 32,377 / 14,210 | 39.8358% | 43.8892% | +4.0534 | 1.101753 |

For **each dimension separately**, reconciling by arm yields 100,058 control and 99,981 treatment clients; positives 60,363 / 63,639; negatives 39,695 / 36,342; total 200,039. Zero invalid or stop rows, zero membership mismatches, zero missing recency, zero segments below support. Source baseline was checked against `stg_uplift_train` within the query. **Gate B: PASS**.

**Critical statistical distinction:** every segment exhibits a positive observed treatment–control RD, but the existence of a within-segment difference does not itself prove *heterogeneity*. The follow-on prespecified comparison is the **difference in RDs** against the same-dimension reference. This is still noncausal, conditional on independent-binomial model assumptions, and exploratory.

**Next Gate C (NOT EXECUTED):** `sql/analysis/06_segment_response_inference.sql` computes RD/RR intervals, within-segment proportion tests (family A), between-segment difference-in-RDs tests (family B) and BH-FDR q-values. BigQuery does not have a native normal-tail CDF; the SQL uses an explicitly named normal-tail approximation and must be checked against independent arithmetic. Do not assert these inferential SQL results until owner execution.

## 5. Contrasts, uncertainty, and multiplicity

For each eligible segment:
- Observed risk difference (RD) = response rate treatment − response rate control, in **percentage points**.
- Observed risk ratio (RR) = response rate treatment / response rate control, if denominator > 0.
- 95% large-sample unpooled Wald CI for RD, log-Katz 95% CI for RR (when positive numerators); explicit assumptions, method and limits. Optionally report Wilson intervals for individual rates, with method named.
- To evaluate **heterogeneity**, compare segment RDs to the reference segment RD within the *same dimension* (frequency reference **Low**, recency reference **Recent**) using a difference-in-RDs statistic and uncertainty under independent disjoint-cell binomial approximations. Significant within-segment RD alone is **not** evidence of interaction/heterogeneity.
- Two predefined multiplicity families: (A) up to six within-segment two-arm comparisons (three per dimension); (B) up to four nonreference versus reference RD contrasts (two per dimension). Apply Benjamini–Hochberg FDR separately per family (nominal 0.05), recording all eligible tests and exclusions. Missing recency is descriptive-only and is not added post hoc to the primary families.
- If percentiles collapse or any cell fails support, flag the limitation; do not cherry-pick remaining significant comparisons. Review the resulting actual family sizes and sensitivity separately.
- These confidence intervals/p-values describe *observational group contrasts under stated statistical assumptions*; they do not identify causal SMS effects.

## 6. Challenge, decision and communication

Before narrating results, check:
- Balance and differential composition across arms by segment; small global SMD values from Session 02 do not guarantee subgroup balance.
- Impact of non-verified feature timing, cutoff ties, outliers, and possible source-label leakage.
- Whether observed global RD +3.3231 pp reconciles to correctly weighted underlying segment rates; do not naïvely average segment RDs.
- Robustness: compare conclusions with one prespecified, separately labeled sensitivity grouping **only if** the primary segmentation has passed its gate, and avoid a search for p < 0.05.
- Executive readout separates **observation**, **assumption**, **hypothesis**, and **next evidence needed**. No ready-to-deploy targeting policy, revenue estimates, causal uplift or ROI.

## 7. Deliverables and workflow

1. **Owner-approved and frozen 2026-11-05:** descriptive frequency and recency dimensions, pooled exact-discrete-tertile rules and numeric thresholds; no target used to select thresholds.
2. **Completed Gate A:** owner executed `sql/analysis/04_segment_distribution_precheck.sql`, supplied two result sets, both dimensions PASS; cutoff values and membership counts documented above.
3. **Completed Gate B:** owner executed `sql/analysis/05_segment_observed_response.sql`, with six `PASS_SUPPORT` statuses and both dimensions `PASS_RECONCILED`; exact arm counts/rates recorded above. **Next:** execute `sql/analysis/06_segment_response_inference.sql` (Gate C) and compare inferential outputs with independent arithmetic.
4. Update README/CHANGELOG/DECISIONS. Note: current README still calls PR #6 Draft even though GitHub confirms it merged; correct this in a separate commit in the same Session 06 feature PR.
5. Evidence of tests/queries **only after the owner has actually run them**; report bytes/costs if measured, never infer actual charges.
6. Review the feature diff; obtain explicit owner approval before squash merge into `main`. Keep the Project Master private. CI/CD is out of scope for this PR.

**Current gate status:** Contract APPROVED, cutoffs FROZEN, Gate A PASS, Gate B PASS (both owner-executed); Gate C inference/FDR SQL NOT RUN; temporal eligibility NOT VERIFIED; causal identification NOT VERIFIED. Versioned SQL alone does not prove execution.
