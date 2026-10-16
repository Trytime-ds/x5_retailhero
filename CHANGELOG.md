# Changelog

## 2026-10-16 — Session 01

### Added
- RAW ingestion scripts for five source tables.
- SQL profiling and source validation queries.
- Experimental data integrity and coverage checks.
- Initial experiment distribution analysis.

### Validated
- 45,786,568 purchase lines.
- 8,045,229 transaction groups.
- Purchase-line composite key uniqueness.
- Consistent purchase_sum within transactions.
- Complete and disjoint train/test client coverage.

### Pending
- Referential integrity and additional Data Quality.
- Experiment validity and temporal leakage assessment.
- dbt staging models.