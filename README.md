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

**Phase 5 — Descriptive customer behavior snapshot mart: QA gate PASS (PR #5 pending review/merge)**

- Created `mart_customer_behavior_snapshot` with one row per client and
  inclusive 30/60/90-day historical ticket windows.
- Executed **9/9 dbt tests PASS** and **9/9 BigQuery reconciliation checks TRUE**.
- Reconciled **400,162** customers, **8,045,229** historical tickets and
  **2,444,257 / 4,534,601 / 6,393,058** tickets in 30/60/90 days.
- Reconciled **36,583,505** product lines in the 90-day window;
  reference date is the **observed** history end (2019-03-18), NOT SMS T0.

**Current focus: validating historical customer behavior and evaluating analytics/experiment design**, with careful restrictions on temporal eligibility and economic interpretation.

Observed treatment/control covariate balance does **not** establish randomization. The intervention time, assignment mechanism and outcome observation window have not been verified. The observed +3.3231 percentage point conversion difference must **not** be interpreted as proven SMS incrementality.

See [technical decisions](docs/DECISIONS.md), [staging contracts and QA evidence](docs/STAGING_CONTRACTS.md), [transaction contracts and QA](docs/INTERMEDIATE_CONTRACTS.md), [customer history contract and QA](docs/CUSTOMER_PURCHASE_HISTORY_CONTRACTS.md), [behavior snapshot contract and QA](docs/CUSTOMER_BEHAVIOR_SNAPSHOT_CONTRACTS.md), [dbt execution instructions](dbt/README.md), and [milestones](CHANGELOG.md).

## Roadmap

- [x] Source ingestion and structural relationship validation
- [x] Targeted RAW Data Quality profiling and preliminary experiment balance
- [x] dbt sources, staging models, initial data tests and row-count reconciliation
- [ ] Broader Data Quality / temporal and experiment validity gates
- [x] Intermediate transaction foundation (PR #3 merged)
- [x] Customer purchase history intermediate foundation (PR #4 merged)
- [x] Descriptive customer behavior snapshot (PR #5 validated; merge pending)
- [ ] Further intermediate models and trusted analytical marts
- [ ] Customer behavior analysis and pre-treatment features
- [ ] Campaign effectiveness and segment-level heterogeneity analysis
- [ ] Post-MVP: individual uplift modeling

---

*This public repository documents an evolving portfolio project. No causal or unsupported revenue claims are made at this stage.*
