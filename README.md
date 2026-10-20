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

**Current focus: intermediate business logic and customer behavioral features**, with careful restrictions on pre-treatment data eligibility and economic metric interpretation.

Observed treatment/control covariate balance does **not** establish randomization. The intervention time, assignment mechanism and outcome observation window have not been verified. The observed +3.3231 percentage point conversion difference must **not** be interpreted as proven SMS incrementality.

See [technical decisions](docs/DECISIONS.md), [staging contracts and QA evidence](docs/STAGING_CONTRACTS.md), [dbt execution instructions](dbt/README.md), and [milestones](CHANGELOG.md).

## Roadmap

- [x] Source ingestion and structural relationship validation
- [x] Targeted RAW Data Quality profiling and preliminary experiment balance
- [x] dbt sources, staging models, initial data tests and row-count reconciliation
- [ ] Broader Data Quality / temporal and experiment validity gates
- [ ] Intermediate transformations and trusted analytical marts
- [ ] Customer behavior analysis and pre-treatment features
- [ ] Campaign effectiveness and segment-level heterogeneity analysis
- [ ] Post-MVP: individual uplift modeling

---

*This public repository documents an evolving portfolio project. No causal or unsupported revenue claims are made at this stage.*
