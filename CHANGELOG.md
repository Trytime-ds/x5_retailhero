# Changelog

## 2026-10-19 — Session 02

### Added
- SQL evidence for products key, purchase/client/product FK integrity and join cardinality.
- Risk-based quantity profiling (zeros, extreme values and vendor/category patterns).
- Client demographics and loyalty-date QA; historical time coverage checks.
- Treatment/control balance checks for gender, frequency and recency, including SMD.

### Validated
- Products: 43,038 distinct IDs in 43,038 rows; no blank/NULL IDs.
- Purchase joins: 45,786,568 rows retained, zero client or product orphans.
- Quantity: 2,707,278 zero lines; no negative/non-numeric/missing; 3 lines >1,000.
- Clients: age and loyalty-date anomalies quantified, without dropping clients.
- Historical purchases: 2018-11-21 to 2019-03-18 (118 active dates).
- Treatment/control SMD: frequency +0.0073; recency -0.0002.

### Limitations / pending
- 44,953 first redemptions occur after observed purchase-history end;
  that date is not verified campaign T0.
- Treatment assignment, exact T0 and outcome window are undocumented;
  observed treatment/control conversion difference is not established as causal.
- purchase_sum meaning, quantity units and monetary QA remain open.
- Next: dbt source declarations, staging type conversions and key data tests.

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

### Pending at Session 01 close
- Referential integrity and additional Data Quality.
- Experiment validity and temporal leakage assessment.
- dbt staging models.
