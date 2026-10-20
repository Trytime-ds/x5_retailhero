# X5 RetailHero — dbt project

dbt Core project for typed, audited staging models built from immutable X5 RetailHero BigQuery RAW tables.

## Local setup

Run commands from the repository root:

```bash
python -m venv .venv
source .venv/Scripts/activate     # Git Bash on Windows
python -m pip install -r requirements.txt
dbt debug --project-dir dbt
```

dbt configuration references the local profile `x5_retailhero_dbt` (not committed). It uses OAuth with the BigQuery project `x5-retailhero-analytics-2026`, development dataset `x5_dbt_dev`, and region `US`. Keep `~/.dbt/profiles.yml` and credentials out of Git.

## Models and QA

```bash
dbt ls --project-dir dbt --resource-type source
dbt run --project-dir dbt --select path:models/staging
dbt test --project-dir dbt --select path:models/staging
```

The five staging views correspond to `clients`, `products`, `purchases`, `uplift_train`, and `uplift_test`; no rows are removed. Execute the four BigQuery reconciliation statements in `sql/qa/08_staging_reconciliation.sql` separately.

See [staging contracts](../docs/STAGING_CONTRACTS.md) for tested behavior, observed QA results and unresolved data semantics. Do not treat the binary experiment outcome as verified causal impact or the repeated `purchase_sum` value as product-line revenue.
