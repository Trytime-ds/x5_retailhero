# Session 06 — Observed response heterogeneity: analytical findings

**Status:** Descriptive analysis Gates A–F completed by project owner on 2026-11-05. Gate G reporting view authored; construction/QA not yet run. PR #7 is Draft and not merged. **This is a noncausal case study; not a validated campaign optimization policy.**

## Executive summary

Across **200,039 labeled training clients**, the source-defined treatment arm had a higher binary positive-outcome rate than control in all six predeclared frequency/recency segments. Differences in observed response rates varied by segment. Three of four **predeclared difference-in-risk-differences comparisons** survived the separate exploratory BH-FDR adjustment at 5%.

- **Frequency of tickets over the observed preceding 90 days:** observed between-arm response RD decreased with frequency: Low **+4.5792 pp**, Medium **+3.2506 pp**, High **+1.4848 pp**. Compared with Low, Medium had an RD **1.3285 pp lower** (BH q=0.013746) and High **3.0944 pp lower** (BH q≈7.09e-11).
- **Recency at observed history end:** observed RD was Recent **+2.5544 pp**, Intermediate **+3.5101 pp**, Less recent **+4.0534 pp**. Compared with Recent, Less recent was **+1.4990 pp** (BH q≈0.004037); Intermediate was +0.9557 pp but **did not pass** BH 5% (q≈0.053686).
- Within-segment observed control response varies strongly by customer activity (frequency Low **35.7847%**, High **85.4046%**): baseline response and outcome-scale/ceiling effects offer alternative explanations for some absolute RD trends.
- Outcome-blind composition diagnostics show small companion-feature SMDs (maximum |SMD| **0.010189**) and small differences in frequency×recency cross-cell arm shares (max absolute **0.1917 pp**). This is **not** evidence of random assignment or absence of unmeasured confounding.

**Recommendation to a CRM decision maker:** Treat these differences as **hypotheses to test in a new, auditable, prospective randomized campaign**, not as evidence that SMS causally lifts lower-frequency or less-recent customers more. No targeting-rule rollout, uplift score, incremental purchase, ROI, or investment decision can be justified from these results alone.

## Data, metric, and method contract

- BigQuery: `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis` (customer grain), population from labeled `stg_uplift_train` only. `stg_uplift_test` has no treatment/target labels and is excluded.
- Source-defined group: `treatment_flg` (0 control, 1 treatment); source-defined binary `target` (0/1). Exact outcome window unknown.
- Historical reference 2019-03-18 is **last observed purchase date, NOT confirmed intervention T0**. Frequency/recency are historical descriptors **not independently certified as pre-SMS covariates**.
- Frozen frequency bins from target-blind `PERCENTILE_DISC`: Low <=8 tickets; Medium 9–18; High >=19. Frozen recency bins: Recent <=2 days; Intermediate 3–7; Less recent >=8. Tie handling preserved; every dimension covers 200,039 clients.
- Observed **risk difference (RD)** in pp = 100 × [Pr(target=1 | treatment_flg=1, segment) – Pr(target=1 | treatment_flg=0, segment)]. Observed **risk ratio (RR)** = first rate divided by second.
- For segment RD, report unpooled large-sample Wald 95% intervals; for RR, log-Katz intervals. For descriptive equality-of-rates, pooled two-proportion z. For **heterogeneity**, compare segment RD with the prespecified **same-dimension, disjoint** reference segment RD (frequency Low / recency Recent), with unpooled standard errors; this is a *difference of observed contrasts*, **not a causal interaction**.
- Two exploratory BH-FDR families at alpha 0.05: A (6 within-segment rate comparisons), B (4 reference contrasts). All six in A meet q<0.05; three of four in B meet q<0.05. Reported 95% CIs are *per-comparison* (not multiplicity-adjusted simultaneous CIs). P-values computed with an explicitly approximate normal tail in versioned BigQuery SQL and cross-checked against independent arithmetic.
- Subgroup tests use disjoint comparisons within a dimension; dimensions reuse the same customers and are correlated. BH and model assumptions limit confirmatory interpretation. Repeated/hypothesis-driven exploratory testing would require a new pre-registration, not post-hoc selection.

## Response and heterogeneity evidence

| Dimension | Segment | N control | N treatment | Control response | Treatment response | Observed RD pp (95% CI) |
|---|---|---:|---:|---:|---:|---|
| Frequency | Low | 35,096 | 34,848 | 35.7847% | 40.3639% | +4.5792 [3.8602, 5.2981] |
| Frequency | Medium | 34,281 | 34,036 | 63.0116% | 66.2622% | +3.2506 [2.5340, 3.9672] |
| Frequency | High | 30,681 | 31,097 | 85.4046% | 86.8894% | +1.4848 [0.9400, 2.0296] |
| Recency | Recent | 38,041 | 38,024 | 78.2077% | 80.7622% | +2.5544 [1.9808, 3.1281] |
| Recency | Intermediate | 29,624 | 29,580 | 59.7759% | 63.2860% | +3.5101 [2.7269, 4.2934] |
| Recency | Less recent | 32,393 | 32,377 | 39.8358% | 43.8892% | +4.0534 [3.2942, 4.8126] |

| Descriptive heterogeneity test (segment minus same-dimension reference) | ΔRD pp (95% CI) | BH family B q | Interpretation |
|---|---|---:|---|
| Frequency Medium − Low | −1.3285 [−2.3436, −0.3135] | 0.013746 | Exploratory evidence of different observed RDs |
| Frequency High − Low | −3.0944 [−3.9964, −2.1924] | 7.092e-11 | Exploratory evidence of different observed RDs |
| Recency Intermediate − Recent | +0.9557 [−0.0152, 1.9266] | 0.053686 | Does not meet BH-FDR 5% |
| Recency Less recent − Recent | +1.4990 [0.5474, 2.4506] | 0.004037 | Exploratory evidence of different observed RDs |

No individual-customer uplift is estimated. The difference between RDs is not itself an estimate of causal treatment-effect heterogeneity.

## Challenge and robustness

**Gates, all owner-run in BigQuery US on 2026-11-05:**
1. Gate A: client-grain distribution, pooled exact discrete tercile cutoffs, zero missing/negative, 200,039 per dimension, no percentile collapse — PASS.
2. Gate B: 6/6 support checks; 2/2 source-arm reconciliations to control n=100,058 (positive=60,363) and treatment n=99,981 (positive=63,639) — PASS.
3. Gate C: six RD/RR intervals, six within-group tests, four reference-RD heterogeneity tests and BH FDR independently recomputed from integer counts — PASS **conditional on statistical assumptions**.
4. Gate D: outcome-blind alternative-feature diagnostics, six companion-feature SMDs all <0.1 in absolute value, maximum 0.010189; 9 frequency×recency cells sum to 200,039 and 100,058/99,981 by arm, with max mix delta 0.1917 pp — PASS for prescribed checks.

**Important alternative explanations / limitations:**
- Randomization protocol, campaign exposure/delivery, intervention T0 and target outcome measurement window are undocumented/unverified. Source group membership is not proof of random assignment; the label `target=1` has no independently verified purchase timestamp.
- History source is described as precommunication, but the cutoff is not independently proven to precede treatment. Leakage/temporal eligibility cannot be ruled out from these metrics.
- Customer activity drives baseline response; with 85% control response in High frequency, the absolute RD is bounded by the outcome scale. RD gradients alone cannot establish a biological/behavioral mechanism or a causal SMS effect.
- Overlap is material: High frequency + Recent = **40,820** customers (20.41% of all labeled); Low frequency + Less recent = **39,247** (19.62%); frequency and recency associations are not additive/independent opportunities.
- Only one companion historical feature SMD within each subgroup was checked. Similar means do not rule out imbalances in unobserved factors or distributional differences.
- No alternative outcome-bearing binning, sample splitting or out-of-sample replication performed; Gate D is a **composition diagnostic**, not a substantive outcome sensitivity analysis.
- Sample is a fixed historical train subset; representativeness for a future live customer population has not been established.

## Part 2: joint composition and scale sensitivity (exploratory)

Owner-executed **Gate E**, `sql/analysis/08_joint_segment_observed_response.sql`,
reconciled nine frozen frequency×recency combinations to 200,039
train customers, with all 9 cells above minimum sample/outcome support;
0 source, count or marginal mismatches. The observed between-arm RD
remains positive in each joint cell, spanning **+1.2808 pp** (High
frequency × Recent) to **+4.8661 pp** (Low frequency × Intermediate).
No new nine-cell significance tests were performed; this is **post hoc
descriptive exploration**, not independent replication of Gate C.

Owner-executed **Gate F**, `sql/analysis/09_joint_composition_standardization.sql`,
produced 7 nonjoint raw vs pooled-joint-cell-weight contrasts and
9 response-ceiling diagnostics; 3/3 QA scope reconciliations PASS,
0 bad weight or marginal checks. Independent arithmetic based on
reported joint-cell counts reproduced all seven contrasts.

- Overall raw observed RD: **+3.3231 pp**; common-weight standardized
  observed RD: **+3.2112 pp**, shift **−0.1119 pp**.
- Across frequency Low/Medium/High, pooled standardized RDs:
  **+4.5723 / +3.2905 / +1.5824 pp**, maintaining the raw gradient.
- Across recency Recent/Intermediate/Less recent, pooled
  standardized RDs **+2.4352 / +3.4709 / +3.8851 pp**, maintaining
  the raw pattern.
- Largest standardization-induced RD change among seven rows:
  **−0.1683 pp** in Less recent.
- High frequency × Recent has control response **90.0305%**, hence
  only **9.9695 pp** mathematical maximum upward room from the
  control baseline. This does not measure a plausible SMS effect.

These findings indicate that the *observed* arm composition within
the joint cells does not overturn the qualitative marginal patterns
under the selected common-weight procedure. This does **not**
establish exchangeability, feature pre-treatment eligibility, the
causal SMS response, or a statistically adjusted confirmation
of the post-hoc nine-cell associations.

**Gate G reporting model proposed, NOT RUN:** the 16-row
`rpt_experiment_response_segments` BigQuery dbt view is authored
with alternative `analysis_scope` categories `overall`,
`frequency`, `recency`, and `joint`. Each scope separately
contains all 200,039 clients, so scopes are **non-additive**.
Model tests and an independent QA script are versioned;
warehouse creation and its outcomes remain pending. The
Power BI dashboard belongs to Session 07.

## Decision memo for CRM

**Observed:** historic customer activity is strongly related to binary response rates; the source-defined treatment/control response gap differs by segment, with adjusted evidence of descriptive heterogeneity in three of four comparisons.

**Hypothesis worth testing:** SMS might be more effective for some low-frequency or less-recent customers than for already highly active customers, or those groups may simply differ in selection, timing, background response propensity, or other unobserved factors.

**Action (research, not rollout):** Design a forward-looking randomized experiment stratified by the *predeclared* frequency/recency groups, using an explicit pre-send feature cutoff; record random assignment, eligibility, send/receipt/exposure events and campaign T0, define outcome metric/window and exclusions in advance, use intention-to-treat as primary, pre-register heterogeneity and multiplicity, size the test for interaction effects, include opt-outs and contact-frequency guardrails, and validate data/financial semantics before any economic claims.

**Do not:** assert incremental SMS purchases, ATE/CATE, individual uplift, ROI, or recommend production targeting based on these historical descriptive comparisons.

## Reproducibility and integration

- Gates A–F: `sql/analysis/04_segment_distribution_precheck.sql` through `09_joint_composition_standardization.sql`. Gates A–F were owner-executed, not CI.
- Numerical detail and source rows: `docs/SEGMENT_HETEROGENEITY_CONTRACTS.md`.
- All reported BigQuery results were **executed by the project owner and shared in conversation**; code was published on the feature branch. The assistant recalculated selected checks; there is **no GitHub Actions CI/warehouse run** or full independent warehouse rerun. Processing bytes/charges have not been reported.
- PR #7 remains Draft; final human review/explicit merge decision pending. A new 16-row **reporting view** is authored but has not yet been created/tested in BigQuery. The existing source-level experiment mart is unchanged. The Project Master remains private.

**Decision status:** analytical reporting **GO WITH LIMITATIONS**; causal identification and deployment **NOT VERIFIED / NOT APPROVED**.
