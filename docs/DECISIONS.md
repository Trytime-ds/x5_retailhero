# Technical Decisions

## DEC-001 — RAW data preservation
Store source columns as STRING in BigQuery RAW.
Type conversion and standardization belong to staging.

## DEC-002 — Purchase granularity
A purchase row represents a product line.
The composite key is:
(client_id, transaction_id, product_id).

## DEC-003 — Transaction amounts
purchase_sum is constant within each transaction group.
Do not aggregate it directly across product lines.
Validate ticket-level monetary semantics before modeling.

## DEC-004 — Experiment structure
uplift_train and uplift_test contain distinct clients
and jointly cover the clients source.

Structural integrity does not establish randomization
or causal validity.