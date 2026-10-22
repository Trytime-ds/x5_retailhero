# Customer Behavior Snapshot — Session 04

**State: DRAFT. Not yet executed or approved.**
The branch contains implementation and QA definitions only.
The project owner must approve analytical semantics before treating
this mart as a valid portfolio deliverable.

## Proposed grain and interpretation

- Model: `mart_customer_behavior_snapshot`; one row per
  `int_customer_purchase_history.client_id` (historical baseline 400,162).
- Reference date: `MAX(observed_history_end_date)` from the validated
  customer history model (historically 2019-03-18). This is **NOT SMS T0**.
- Windows: last 30 calendar dates are day offsets **0 through 29**,
  last 60 = **0 through 59**, last 90 = **0 through 89**.
  Windows include the reference date.
- Metrics: ticket frequency over 30/60/90 days, active purchase days
  over 30/60/90 days, distinct stores and product-line activity over
  90 days, plus already validated observed-history totals and recency.
- For a client with no tickets in a window, count metrics are zero.
  Undefined recency from an absent lifetime-history remains NULL.
- Source history currently spans more than 90 calendar days. That
  temporal range does **not** independently establish complete history
  for each client or a valid treatment time.
- There are no product-unit totals, revenue aggregates, RFM monetary
  scores, treatment flags, outcomes, or temporally ambiguous loyalty
  attributes.
- No lifecycle segment labels or thresholds are imposed without
  examining distributions and getting analytical approval.
- Materialization: BigQuery table; no clustering or partitioning
  specified until query patterns justify the added configuration.

## Validation gate — pending owner execution

1. `dbt ls --project-dir dbt --select mart_customer_behavior_snapshot`
2. `dbt run --project-dir dbt --select mart_customer_behavior_snapshot`
3. `dbt test --project-dir dbt --select mart_customer_behavior_snapshot`
4. BigQuery US: `sql/qa/11_customer_behavior_snapshot_reconciliation.sql`

Expect **nine TRUE booleans** in the reconciliation; dynamic rolling
window totals should match the source and MUST NOT be predeclared.

## Decisions to review

- Descriptive reference date versus verified pre-treatment T0:
  **keep the explicit observed-history distinction**.
- 30/60/90 inclusive calendar windows: **proposed**, not yet
  formally signed off for downstream campaign modeling.
- No segmentation thresholds, demographics, finance or experiment
  variables until a separate decision.
- CI not configured: local owner-executed evidence is required.
