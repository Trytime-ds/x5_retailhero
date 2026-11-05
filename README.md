# X5 RetailHero — Customer Growth & Experimentation Analytics

**🚧 Work in Progress — Under Active Development**

## Overview

An end-to-end retail analytics project focused on understanding customer behavior, evaluating SMS marketing campaigns, and developing better customer targeting strategies.

The central business question is:

**Which customers are more likely to purchase because of a campaign, rather than purchase anyway?**

The project combines SQL-based analysis, analytics engineering, customer segmentation and experimentation. Individual uplift modeling is a post-MVP extension.

## Tech Stack

**Google Cloud Storage · BigQuery · SQL · dbt Core · Python (post-MVP) · Git**

## Current Progress

**Phase 1 — RAW Data Foundation: Completed**

- Ingested five sources into BigQuery.
- Profiled over 45 million purchase product lines.
- Validated purchase grain, primary-key candidates, client/product relationships and join cardinality.
- Performed targeted quantity, demographics and loyalty-date QA.
- Assessed source historical time coverage and measured treatment/control covariate balance.

**Phase 2 — dbt source registration and staging: Technical gate PASS**

- Defined five RAW sources and created five typed, one-to-one staging views.
- Executed **20/20 passing dbt data tests**.
- Reconciled **5/5 RAW-to-staging row counts** and preserved documented purchase/client anomalies.
- Retained flagged unusual values, rather than deleting or silently correcting data.

**Phase 3 — Intermediate transaction model: Technical and reconciliation gate PASS (PR #3 merged)**

- Constructed `int_transactions` at one row per client×transaction, materialized
  as a BigQuery table partitioned by transaction date and clustered by client.
- Executed **10/10 passing dbt tests** and **6/6 passing BigQuery QA checks**.
- Reconciled **8,045,229 transactions** and all **45,786,568 product lines**,
  including 2,707,278 zero-quantity lines and three extreme-quantity lines.
- Retained `purchase_sum_reported` once per ticket without asserting its
  business/currency semantics. Integrated into `main` via PR #3.

**Phase 4 — Customer purchase history: Technical and reconciliation gate PASS (PR #4 merged)**

- Built `int_customer_purchase_history` at one row per client, with
  observed ticket frequency, days active, store diversity and historical recency.
- Executed **8/8 passing dbt tests** and **8/8 passing BigQuery reconciliations**.
- Reconciled **400,162** distinct clients, **8,045,229** tickets and
  **45,786,568** original lines, with zero/excess-quantity counts conserved.
- All source clients currently have historical purchases; no-purchase
  handling remains a defensive contract for future updates.
- `2019-03-18` is the observed history end, **not** confirmed campaign T0.

**Phase 5 — Descriptive customer behavior snapshot mart: QA gate PASS (PR #5 merged)**

- Created `mart_customer_behavior_snapshot` with one row per client and
  inclusive 30/60/90-day historical ticket windows.
- Executed **9/9 dbt tests PASS** and **9/9 BigQuery reconciliation checks TRUE**.
- Reconciled **400,162** customers, **8,045,229** historical tickets and
  **2,444,257 / 4,534,601 / 6,393,058** tickets in 30/60/90 days.
- Reconciled **36,583,505** product lines in the 90-day window;
  reference date is the **observed** history end (2019-03-18), NOT SMS T0.

**Phase 6 — Observed experiment response analytics: Technical QA PASS (PR #6 merged)**

- Documented and owner-approved the experiment analysis contract for the
  200,039 labeled training clients; validated source population and left-join
  cardinality using owner-run BigQuery checks.
- Versioned `mart_experiment_analysis` SQL, schema and singular dbt tests,
  independent post-build QA, source prechecks, and a descriptive comparison query.
- Owner-run `dbt run` 1/1 PASS (15.55 s), `dbt test` 17/17 PASS
  (20.77 s), and 16/16 TRUE post-build BigQuery QA flags.
- Exactly **200,039 distinct train clients** preserved without missing
  customers, incorrect treatment/outcome values, or descriptive-history mismatches.
- Owner-run inferential comparison: observed difference **+3.3231 pp**
  (95% CI **+2.8979 to +3.7483 pp**), z=15.3093 and two-sided
  p < 1e-10 under large-sample independent-binomial assumptions.
  These are **observed differences, not verified causal SMS effects**.
- PR #6 was squash-merged to `main` on 2026-11-02 (Chile time), commit `6210d9c`.
  Processing-cost evidence remains unavailable; validations were manual, **not CI**.
- Source-defined treatment/control comparison is descriptive; randomization,
  SMS T0, actual delivery and outcome window are not independently verified.

**Phase 7 — Descriptive response heterogeneity: Gates A–D PASS (Draft PR #7)**

- Frozen outcome-blind segment cutoffs across **200,039** train clients:
  frequency 90d Low 1–8 / Medium 9–18 / High 19+ tickets;
  recency Recent 0–2 / Intermediate 3–7 / Less recent 8+ days.
- Owner executed four versioned BigQuery scripts: distribution, arm-level
  descriptive response, conditional inference/FDR and composition/overlap QA.
  Gates A–D PASS within declared scope; no extra dbt mart or CI execution.
- Observed source-defined treatment−control response RD by frequency:
  **+4.5792 / +3.2506 / +1.4848 pp** (Low/Medium/High); by recency:
  **+2.5544 / +3.5101 / +4.0534 pp** (Recent/Intermediate/Less recent).
- Prespecified descriptive difference-in-RD tests with BH-FDR: **3 of 4**
  contrasts have q<0.05. This is not an identified causal SMS effect.
- Outcome-blind composition checks: all 6 companion SMD values below
  0.1 absolute; 9 cross-cells reconcile all 200,039 train clients.
- [Analytical findings and CRM decision memo](docs/SESSION_06_ANALYTICAL_FINDINGS.md)
  and [full segment contract and QA](docs/SEGMENT_HETEROGENEITY_CONTRACTS.md).
  PR #7 remains **Draft / awaiting owner review and explicit merge approval**.

**Current focus: descriptive segment heterogeneity, interpretation and review of PR #7**, with explicit restrictions on temporal eligibility and causal/economic interpretation.

Observed treatment/control covariate balance does **not** establish randomization. The intervention time, assignment mechanism and outcome observation window have not been verified. The observed +3.3231 percentage point source-defined binary response difference must **not** be interpreted as proven SMS incrementality.

See [technical decisions](docs/DECISIONS.md), [staging contracts and QA evidence](docs/STAGING_CONTRACTS.md), [transaction contracts and QA](docs/INTERMEDIATE_CONTRACTS.md), [customer history contract and QA](docs/CUSTOMER_PURCHASE_HISTORY_CONTRACTS.md), [behavior snapshot contract and QA](docs/CUSTOMER_BEHAVIOR_SNAPSHOT_CONTRACTS.md), [experiment contract and QA evidence](docs/EXPERIMENT_ANALYSIS_CONTRACTS.md), [dbt execution instructions](dbt/README.md), and [milestones](CHANGELOG.md).

## Roadmap

- [x] Source ingestion and structural relationship validation
- [x] Targeted RAW Data Quality profiling and preliminary experiment balance
- [x] dbt sources, staging models, initial data tests and row-count reconciliation
- [ ] Broader Data Quality / temporal and experiment validity gates
- [x] Intermediate transaction foundation (PR #3 merged)
- [x] Customer purchase history intermediate foundation (PR #4 merged)
- [x] Descriptive customer behavior snapshot (PR #5 validated and merged)
- [x] Experiment response analysis mart technical QA (PR #6 merged)
- [ ] Further intermediate models and trusted analytical marts
- [ ] Customer behavior analysis and pre-treatment features
- [x] Descriptive segment-level response heterogeneity (Gates A–D; PR #7 pending merge)
- [ ] Verified prospective campaign effectiveness / causal experiment
- [ ] Post-MVP: individual uplift modeling

---

*This public repository documents an evolving portfolio project. No causal or unsupported revenue claims are made at this stage.*
