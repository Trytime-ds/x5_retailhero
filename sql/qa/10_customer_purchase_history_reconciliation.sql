-- Session 04 / BigQuery US. Execute after dbt builds the customer summary.
-- Aggregates compare stg_clients, int_transactions, and the new customer model.
WITH client_source AS (
    SELECT COUNT(*) AS source_clients
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_clients`
),
transaction_source AS (
    SELECT
        COUNT(*) AS source_transactions,
        COUNT(DISTINCT client_id) AS clients_with_transactions,
        SUM(line_count) AS source_purchase_lines,
        SUM(zero_quantity_line_count) AS source_zero_qty_lines,
        SUM(extreme_quantity_line_count) AS source_extreme_qty_lines,
        MAX(transaction_date) AS source_history_end_date
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.int_transactions`
),
customer_model AS (
    SELECT
        COUNT(*) AS model_clients,
        COUNT(DISTINCT client_id) AS model_distinct_clients,
        COUNTIF(has_purchase_history) AS model_active_clients,
        SUM(transaction_count) AS model_transactions,
        SUM(purchase_line_count) AS model_purchase_lines,
        SUM(zero_quantity_line_count) AS model_zero_qty_lines,
        SUM(extreme_quantity_line_count) AS model_extreme_qty_lines,
        COUNTIF(observed_history_end_date IS NULL) AS null_anchor_clients,
        COUNTIF(
            has_purchase_history
            AND (recency_days_at_history_end IS NULL OR recency_days_at_history_end < 0)
        ) AS bad_recency_clients,
        COUNTIF(NOT has_purchase_history AND recency_days_at_history_end IS NOT NULL)
            AS inactive_clients_with_recency,
        MIN(observed_history_end_date) AS model_min_history_end_date,
        MAX(observed_history_end_date) AS model_max_history_end_date
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.int_customer_purchase_history`
)
SELECT
    c.source_clients, m.model_clients, m.model_distinct_clients,
    t.source_transactions, m.model_transactions,
    t.clients_with_transactions, m.model_active_clients,
    t.source_purchase_lines, m.model_purchase_lines,
    t.source_zero_qty_lines, m.model_zero_qty_lines,
    t.source_extreme_qty_lines, m.model_extreme_qty_lines,
    t.source_history_end_date,
    m.model_min_history_end_date, m.model_max_history_end_date,
    m.null_anchor_clients, m.bad_recency_clients,
    m.inactive_clients_with_recency,
    m.model_clients = c.source_clients
        AND m.model_distinct_clients = c.source_clients AS client_coverage_pass,
    m.model_transactions = t.source_transactions AS transaction_reconciliation_pass,
    m.model_active_clients = t.clients_with_transactions AS active_clients_pass,
    m.model_purchase_lines = t.source_purchase_lines AS purchase_lines_pass,
    m.model_zero_qty_lines = t.source_zero_qty_lines AS zero_qty_pass,
    m.model_extreme_qty_lines = t.source_extreme_qty_lines AS extreme_qty_pass,
    m.null_anchor_clients = 0
        AND m.model_min_history_end_date = t.source_history_end_date
        AND m.model_max_history_end_date = t.source_history_end_date AS history_anchor_pass,
    m.bad_recency_clients = 0
        AND m.inactive_clients_with_recency = 0 AS recency_consistency_pass
FROM client_source AS c
CROSS JOIN transaction_source AS t
CROSS JOIN customer_model AS m;
