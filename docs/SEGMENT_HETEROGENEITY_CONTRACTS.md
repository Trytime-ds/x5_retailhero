# Session 06 — Descriptive Response Heterogeneity Contract

**Status:** DRAFT — pending owner review. No Session 06 segment outcome queries or tests have been executed.
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

For **each dimension separately**, derive exact empirical 33rd and 67th percentile cutoffs (`PERCENTILE_DISC` at 1/3 and 2/3, if supported in the deployed BigQuery dialect) **from all 200,039 train clients pooled**, never stratified by treatment or target. Ignore missing observations for computing recency cutoffs, but retain them as a separate Missing segment.

- Frequency: **Low** `x <= q33`; **Medium** `q33 < x <= q67`; **High** `x > q67`.
- Recency: **Recent** `x <= q33`; **Intermediate** `q33 < x <= q67`; **Less recent** `x > q67`. Missing stays separate.
- Preserve ties: all customers with the same value belong to the same segment. Percentiles are *cutoff values*, not a guarantee of equal group sizes.
- If `q33 >= q67`, segment boundaries collapse. **STOP / request a revised threshold contract before outcome-based segmentation**; do not quietly switch to arbitrary thresholds or select cutoffs based on observed effects.
- Record cutoff values, percentile method, distribution counts, missingness, observed source data version/cutoff, and any zero-value concentration as reproducibility evidence.
- No segment may be selected, excluded, or redefined using `target`, observed treatment/control difference, confidence intervals, or p-values.

### Pre-outcome gate A (required)

Create and execute a **distribution-only** BigQuery query showing for each dimension: min/p33/median/p67/max, missing count, number of distinct values, zero count, cutoff-tie frequencies, and final segment counts **without any treatment or outcome columns**. Check exactly 200,039 assigned clients per dimension, no duplication and no loss. Owner must review/freeze cutoff values *before* the segment response query is written/executed.

## 4. Minimum cell support and QA

Once boundaries are frozen, calculate by dimension × segment × arm:
- `n_clients = COUNT(*)` (unique customer grain), `positive = COUNTIF(target=1)`, `negative = COUNTIF(target=0)`, `response_rate = positive / n_clients`.
- Preserve the original control and treatment totals across the segments for **each** dimension; group contributions must reconcile to 100,058 control, 99,981 treatment, 60,363 control positives, and 63,639 treatment positives.
- Inferential reporting eligibility requires **n >= 500 in each arm AND >= 30 positives and >= 30 negatives per arm**. These thresholds are conservative *analysis safeguards*, not proof of normality or unbiased sampling.
- For insufficient cells: show counts descriptively, flag `INSUFFICIENT_SUPPORT`, and **suppress inferential claims** rather than dropping customers or changing boundaries in response to outcomes.
- Do not interpret numerical rates for `n=0`; use NULL and explicit status.
- Unexpected treatment/target values, duplicated client IDs, missing source rows or misclassified boundaries are QA failures.

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

1. Owner review of this **draft contract**, then freeze eligibility and segmentation decisions.
2. Distribution-only profiling SQL and owner-executed evidence (Gate A).
3. Segment-rate descriptive SQL, inferential/interaction SQL, multiplicity checks, independent reconciliation QA, documented limitations.
4. Update README/CHANGELOG/DECISIONS. Note: current README still calls PR #6 Draft even though GitHub confirms it merged; correct this in a separate commit in the same Session 06 feature PR.
5. Evidence of tests/queries **only after the owner has actually run them**; report bytes/costs if measured, never infer actual charges.
6. Review the feature diff; obtain explicit owner approval before squash merge into `main`. Keep the Project Master private. CI/CD is out of scope for this PR.

**Current gate status:** Contract DRAFT; temporal eligibility NOT VERIFIED; distribution and response segment QA NOT RUN; causal identification NOT VERIFIED.
