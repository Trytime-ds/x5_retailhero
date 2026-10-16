# X5 RetailHero — Customer Growth & Experimentation Analytics

**🚧 Work in Progress — Under Active Development**

## Overview

An end-to-end retail analytics project focused on understanding customer behavior, measuring the incremental impact of SMS marketing campaigns, and developing more effective customer targeting strategies.

The central business question is:

**Which customers are more likely to purchase because of a campaign, rather than purchase anyway?**

The project combines SQL-based data analysis, analytics engineering, customer segmentation, and experimentation, with uplift modeling planned for a later phase.

## Tech Stack

**Google Cloud Storage · BigQuery · SQL · dbt (planned) · Python (planned) · Git**

## Current Progress

**Phase 1 — Data Foundation: Completed**

- Ingested five source datasets into BigQuery.
- Profiled over 45 million purchase records.
- Validated purchase granularity and candidate keys.
- Completed initial experimental dataset integrity checks.

**Current focus:** Data quality, referential integrity, experimental validity, and temporal leakage assessment.

## Roadmap

- [x] Data ingestion and initial source validation
- [ ] Data quality and experiment validation
- [ ] dbt transformations and trusted data models
- [ ] Customer behavior analysis and feature engineering
- [ ] Campaign effectiveness and segment-level uplift analysis
- [ ] Post-MVP: Predictive uplift modeling

---

*This repository documents an ongoing portfolio project. Analytical findings, models, and documentation will be expanded as development progresses. No causal conclusions are claimed at this stage.*