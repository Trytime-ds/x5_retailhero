# X5 RetailHero — Customer Growth & Experimentation Analytics

**🚧 Work in Progress — Under Active Development**

## Overview

An end-to-end retail analytics project focused on understanding customer behavior, evaluating SMS marketing campaigns, and developing better customer targeting strategies.

The central business question is:

**Which customers are more likely to purchase because of a campaign, rather than purchase anyway?**

The project combines SQL-based analysis, analytics engineering, customer segmentation and experimentation. Individual uplift modeling is a post-MVP extension.

## Tech Stack

**Google Cloud Storage · BigQuery · SQL · dbt (planned) · Python (post-MVP) · Git**

## Current Progress

**Phase 1 — RAW Data Foundation: Completed**

- Ingested five sources into BigQuery.
- Profiled over 45 million purchase product lines.
- Validated purchase grain, primary-key candidates, client/product relationships and join cardinality.
- Performed targeted quantity, demographics and loyalty-date QA.
- Assessed source historical time coverage and measured treatment/control covariate balance.

**Current focus: dbt source declarations, staging casts and risk-based tests.** The analyzed groups show good balance on the observed covariates; nevertheless, treatment randomization, exact campaign timing and outcome window have not been confirmed. The observed +3.3231 percentage point conversion difference must **not** be interpreted as proven SMS incrementality.

See [`docs/DECISIONS.md`](docs/DECISIONS.md) for evidence, limitations and technical decisions; [`CHANGELOG.md`](CHANGELOG.md) for milestones.

## Roadmap

- [x] Source ingestion and structural relationship validation
- [x] Targeted RAW Data Quality profiling and preliminary experiment balance
- [ ] Full Data Quality / temporal and experiment validity gates
- [ ] dbt transformations and trusted data models
- [ ] Customer behavior analysis and pre-treatment features
- [ ] Campaign effectiveness and segment-level heterogeneity analysis
- [ ] Post-MVP: individual uplift modeling

---

*This public repository documents an evolving portfolio project. No causal or unsupported revenue claims are made at this stage.*
