# Session 06 — Descriptive Response Heterogeneity Contract

**Status:** Owner-executed Gates A, B, C and D PASS within their descriptive/statistical scope on 2026-11-05; frequency/recency boundaries FROZEN. PR #7 under review, NOT merged. Causal/temporal validity NOT VERIFIED.
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

**Gate A status: PASS — cutoffs and membership counts frozen.** No outcome-bearing query was run to select thresholds. Subsequent per-arm Gate B also passed.

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

**Gate C executed 2026-11-05:** Owner ran `sql/analysis/06_segment_response_inference.sql` in BigQuery and supplied both result sets. See detailed evidence in §5. Independently recomputed from the owner-provided *integer counts*, not from direct warehouse execution, the 6 observed RD/RR CIs, 6 pooled two-proportion z tests, 4 difference-in-RDs tests and BH-FDR values. Agreement within displayed precision: **PASS under the explicitly conditional statistical assumptions**.

## 5. Contrasts, uncertainty, and multiplicity

For each eligible segment:
- Observed risk difference (RD) = response rate treatment − response rate control, in **percentage points**.
- Observed risk ratio (RR) = response rate treatment / response rate control, if denominator > 0.
- 95% large-sample unpooled Wald CI for RD, log-Katz 95% CI for RR (when positive numerators); explicit assumptions, method and limits. Optionally report Wilson intervals for individual rates, with method named.
- To evaluate **heterogeneity**, compare segment RDs to the reference segment RD within the *same dimension* (frequency reference **Low**, recency reference **Recent**) using a difference-in-RDs statistic and uncertainty under independent disjoint-cell binomial approximations. Significant within-segment RD alone is **not** evidence of interaction/heterogeneity.
- Two predefined multiplicity families: (A) up to six within-segment two-arm comparisons (three per dimension); (B) up to four nonreference versus reference RD contrasts (two per dimension). Apply Benjamini–Hochberg FDR separately per family (nominal 0.05), recording all eligible tests and exclusions. Missing recency is descriptive-only and is not added post hoc to the primary families.
- If percentiles collapse or any cell fails support, flag the limitation; do not cherry-pick remaining significant comparisons. Review the resulting actual family sizes and sensitivity separately.
- These confidence intervals/p-values describe *observational group contrasts under stated statistical assumptions*; they do not identify causal SMS effects.

### Gate C execution evidence — owner-reported 2026-11-05

Executed `sql/analysis/06_segment_response_inference.sql` in BigQuery US; **two result sets provided**. Independent reference calculation from exact arm counts using normal survival probability (`erfc`), Wald RD intervals, log-Katz RR intervals and BH step-up (families sized 6 and 4) reconciles with the BigQuery approximation to displayed precision. **No CI/warehouse run by GitHub or the assistant.**

**Family A: six within-segment source-defined treatment/control comparisons** (all six BH-adjusted q < 0.05; not proof of causal SMS effect).

| Dimension | Segment | RD pp | RD 95% CI pp | RR | RR 95% CI | Approx. p | BH q |
|---|---|---:|---|---:|---|---:|---:|
| Frequency | Low | 4.5792 | [3.8602, 5.2981] | 1.127964 | [1.106785, 1.149548] | 1.07717e-35 | 6.46302e-35 |
| Frequency | Medium | 3.2506 | [2.5340, 3.9672] | 1.051588 | [1.039978, 1.063327] | 6.38306e-19 | 1.27661e-18 |
| Frequency | High | 1.4848 | [0.9400, 2.0296] | 1.017385 | [1.010968, 1.023843] | 9.18991e-8 | 9.18991e-8 |
| Recency | Recent | 2.5544 | [1.9808, 3.1281] | 1.032662 | [1.025228, 1.040150] | 2.70496e-18 | 3.24595e-18 |
| Recency | Intermediate | 3.5101 | [2.7269, 4.2934] | 1.058722 | [1.045307, 1.072308] | 1.67314e-18 | 2.50971e-18 |
| Recency | Less recent | 4.0534 | [3.2942, 4.8126] | 1.101753 | [1.081896, 1.121975] | 1.38511e-25 | 4.15534e-25 |

**Family B: four prespecified descriptive heterogeneity contrasts, difference in observed RDs against same-dimension reference**:

| Dimension | Segment − reference | ΔRD pp | 95% CI pp | z | Approx. p | BH q | BH q < 0.05 |
|---|---|---:|---|---:|---:|---:|---|
| Frequency | Medium − Low | −1.3285 | [−2.3436, −0.3135] | −2.5653 | 0.01030985 | 0.01374647 | YES |
| Frequency | High − Low | −3.0944 | [−3.9964, −2.1924] | −6.7236 | 1.77305e-11 | 7.09218e-11 | YES |
| Recency | Intermediate − Recent | +0.9557 | [−0.0152, 1.9266] | 1.9294 | 0.05368609 | 0.05368609 | NO |
| Recency | Less recent − Recent | +1.4990 | [0.5474, 2.4506] | 3.0875 | 0.00201852 | 0.00403704 | YES |

**Gate C status: PASS conditional.** Three of four Family B comparisons meet BH q < 0.05, while Recency Intermediate vs Recent does not. CIs shown are **individual unadjusted 95% CIs**; the BH decision uses adjusted *p-values*, not simultaneous confidence intervals. Both families include comparisons based on the same source population across dimensions, so dependence and confirmatory FDR guarantees warrant caution. The source history may not be pre-treatment; segment comparisons are descriptive, and no causal SMS targeting claims are identified. Comparisons of a subgroup RD against the global RD would be statistically dependent; the reported Family B instead uses disjoint reference groups *within each dimension*.

**Review challenge:** Strong gradients in baseline control response could produce bounded-outcome/ceiling effects (frequency High control ~85.4%, frequency Low control ~35.8%). Differences on an absolute risk scale depend on baseline risk. Evaluate historical covariate composition and group overlap before writing CRM conclusions.

## 6. Challenge, decision and communication

Before narrating results, check:
- Balance and differential composition across arms by segment; small global SMD values from Session 02 do not guarantee subgroup balance.
- Impact of non-verified feature timing, cutoff ties, outliers, and possible source-label leakage.
- Whether observed global RD +3.3231 pp reconciles to correctly weighted underlying segment rates; do not naïvely average segment RDs.
- Robustness: compare conclusions with one prespecified, separately labeled sensitivity grouping **only if** the primary segmentation has passed its gate, and avoid a search for p < 0.05.
- Executive readout separates **observation**, **assumption**, **hypothesis**, and **next evidence needed**. No ready-to-deploy targeting policy, revenue estimates, causal uplift or ROI.

### Gate D — planned (NOT EXECUTED): composition and overlap diagnostics

Following Gate C PASS, run `sql/analysis/07_segment_composition_diagnostics.sql` in BigQuery US as a **descriptive robustness check** without reading `target` or changing the frozen boundaries.

- **Output 1:** within each frequency segment, compare recency by source-defined arm; within each recency segment, compare 90-day ticket frequency by arm. Report means, medians, standardized mean differences (SMD) and diagnostic flags. Flag |SMD| ≥ 0.1 for review, not as a formal experiment-balance pass/fail criterion.
- **Output 2:** nine cells crossing the frozen frequency × recency segments (or fewer if a cell is empty), with counts for both arms and their share of the full respective arm. This reveals overlap/dependence of the two dimensions and differences in observed mix.
- **Guardrails:** verify exact source 200,039 unique clients, 100,058 controls, 99,981 treatments, six frozen memberships. The script has no outcome variable; it does not attempt to estimate adjusted causal effects or infer randomization from covariate balance.
- **Interpretation:** a large overlap or composition difference may help explain observed gradients. No predefined additional outcome segmentation is authorized; a post-hoc sensitivity analysis would need separate labeling and justification.

### Gate D owner execution evidence — 2026-11-05

Owner executed `sql/analysis/07_segment_composition_diagnostics.sql` in BigQuery US and shared **both result sets**; the assistant independently summed 9 cross-cells and their arm counts. No CI or independent warehouse execution is claimed.

**Outcome-blind companion-feature diagnostics (control vs treatment within the frozen segment):**

| Dimension | Segment | Companion | Control mean / median | Treatment mean / median | SMD | Gate flag |
|---|---|---|---|---|---:|---|
| Frequency | Low | Recency (days) | 9.0883 / 8 | 9.0987 / 8 | +0.001764 | NO_LARGE_SMD_OBSERVED |
| Frequency | Medium | Recency (days) | 5.4082 / 4 | 5.4265 / 4 | +0.003579 | NO_LARGE_SMD_OBSERVED |
| Frequency | High | Recency (days) | 2.5722 / 1 | 2.6032 / 1 | +0.008661 | NO_LARGE_SMD_OBSERVED |
| Recency | Recent | 90d transactions | 23.6338 / 20 | 23.7191 / 20 | +0.005087 | NO_LARGE_SMD_OBSERVED |
| Recency | Intermediate | 90d transactions | 13.9264 / 12 | 14.0282 / 12 | +0.009821 | NO_LARGE_SMD_OBSERVED |
| Recency | Less recent | 90d transactions | 8.7603 / 7 | 8.8382 / 7 | +0.010189 | NO_LARGE_SMD_OBSERVED |

Maximum absolute companion SMD = **0.010189**, below review threshold **0.1** in all six groups. This only checks one **other historical metric** at a time, not all confounders or assignment validity.

**Frequency × recency overlap (outcome-blind):**

| Frequency | Recency | Clients | Control | Treatment | Treatment minus control mix (pp of respective arm) |
|---|---|---:|---:|---:|---:|
| Low | Recent | 9,944 | 5,001 | 4,943 | -0.0542 |
| Low | Intermediate | 20,753 | 10,374 | 10,379 | +0.0130 |
| Low | Less recent | 39,247 | 19,721 | 19,526 | -0.1799 |
| Medium | Recent | 25,301 | 12,718 | 12,583 | -0.1252 |
| Medium | Intermediate | 23,426 | 11,780 | 11,646 | -0.1250 |
| Medium | Less recent | 19,590 | 9,783 | 9,807 | +0.0315 |
| High | Recent | 40,820 | 20,322 | 20,498 | +0.1917 |
| High | Intermediate | 15,025 | 7,470 | 7,555 | +0.0908 |
| High | Less recent | 5,933 | 2,889 | 3,044 | +0.1573 |

**Independent aggregate reconciliation:** cross-cells sum to **200,039 clients**, **100,058 control**, **99,981 treatment**. Frequency marginals: 69,944 / 68,317 / 61,778. Recency marginals: 76,065 / 59,204 / 64,770. Largest absolute arm-composition delta in a cross-cell = **0.1917 percentage points**. Strong overlap: High+Recent = 40,820 (20.41% of train) while Low+Less recent = 39,247 (19.62%); High+Less recent = 5,933 (2.97%). These dimensions are related and their subgroup observations **cannot be added together as independent opportunities**.

**Gate D: PASS for predeclared outcome-blind composition diagnostics and reconciliation.** This is NOT a prospective sensitivity test on outcome data, a causal adjustment, proof of pre-SMS timing, verified randomization or absence of unobserved confounding.

**Remaining:** executive/technical narrative, portfolio documentation hygiene, final PR review and explicit merge decision. No automated dbt/CI execution occurred for Session 06.


## 7. Deliverables and workflow

1. **Owner-approved and frozen 2026-11-05:** descriptive frequency and recency dimensions, pooled exact-discrete-tertile rules and numeric thresholds; no target used to select thresholds.
2. **Completed Gate A:** owner executed `sql/analysis/04_segment_distribution_precheck.sql`, supplied two result sets, both dimensions PASS; cutoff values and membership counts documented above.
3. **Completed Gate B/C:** owner executed `sql/analysis/05_segment_observed_response.sql` (six `PASS_SUPPORT`, both dimensions `PASS_RECONCILED`) and `sql/analysis/06_segment_response_inference.sql` (CIs, z, p approx. and BH q independently reconciled). **Next:** robustness / descriptive composition diagnostics and stakeholder interpretation.
4. **Next:** execute outcome-blind `sql/analysis/07_segment_composition_diagnostics.sql` and review SMD/overlap before stakeholder readout. Update README/CHANGELOG/DECISIONS (README still calls merged PR #6 Draft).
5. Evidence of tests/queries **only after the owner has actually run them**; report bytes/costs if measured, never infer actual charges.
6. Review the feature diff; obtain explicit owner approval before squash merge into `main`. Keep the Project Master private. CI/CD is out of scope for this PR.

**Current gate status:** Contract APPROVED; cutoffs FROZEN; Gates A, B, D PASS and C PASS conditional (all owner-executed). Technical statistical readout completed; executive interpretation and final review in progress. Temporal eligibility and causal identification NOT VERIFIED. PR #7 remains Draft/unmerged. Versioned SQL alone does not prove execution.
