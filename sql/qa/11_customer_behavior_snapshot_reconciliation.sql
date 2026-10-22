-- Session 04 / BigQuery US: run after the dbt behavior snapshot has built.
-- This independently reconciles rolling transaction counts and line totals.
-- Windows include the snapshot date (offsets 0..29, 0..59, 0..89).
WITH bounds AS (
    SELECT MAX(observed_history_end_date) AS snapshot_date
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.int_customer_purchase_history`
),
source_transactions AS (
    SELECT
        COUNT(*) AS all_tickets,
        COUNTIF(DATE_DIFF(b.snapshot_date, t.transaction_date, DAY)
            BETWEEN 0 AND 29) AS source_transactions_30d,
        COUNTIF(DATE_DIFF(b.snapshot_date, t.transaction_date, DAY)
            BETWEEN 0 AND 59) AS source_transactions_60d,
        COUNTIF(DATE_DIFF(b.snapshot_date, t.transaction_date, DAY)
            BETWEEN 0 AND 89) AS source_transactions_90d,
        SUM(IF(DATE_DIFF(b.snapshot_date, t.transaction_date, DAY)
            BETWEEN 0 AND 89, t.line_count, 0))
            AS source_purchase_lines_90d,
        MIN(t.transaction_date) AS observed_start_date
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.int_transactions` AS t
    CROSS JOIN bounds AS b
),
mart_metrics AS (
    SELECT
        COUNT(*) AS mart_rows,
        COUNT(DISTINCT client_id) AS distinct_clients,
        SUM(transactions_observed_total) AS mart_all_tickets,
        SUM(transactions_30d) AS mart_transactions_30d,
        SUM(transactions_60d) AS mart_transactions_60d,
        SUM(transactions_90d) AS mart_transactions_90d,
        SUM(purchase_lines_90d) AS mart_purchase_lines_90d,
        MIN(observed_snapshot_date) AS min_snapshot_date,
        MAX(observed_snapshot_date) AS max_snapshot_date,
        COUNTIF(transactions_30d > transactions_60d
             OR transactions_60d > transactions_90d
             OR transactions_90d > transactions_observed_total)
            AS invalid_window_rows
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_customer_behavior_snapshot`
),
universe AS (
    SELECT COUNT(*) AS source_clients
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.int_customer_purchase_history`
)
SELECT
    b.snapshot_date, s.observed_start_date,
    u.source_clients, m.mart_rows, m.distinct_clients,
    s.all_tickets, m.mart_all_tickets,
    s.source_transactions_30d, m.mart_transactions_30d,
    s.source_transactions_60d, m.mart_transactions_60d,
    s.source_transactions_90d, m.mart_transactions_90d,
    s.source_purchase_lines_90d, m.mart_purchase_lines_90d,
    m.invalid_window_rows,
    m.mart_rows = u.source_clients
        AND m.distinct_clients = u.source_clients AS client_universe_pass,
    m.mart_all_tickets = s.all_tickets AS historical_tickets_pass,
    m.mart_transactions_30d = s.source_transactions_30d AS window_30d_pass,
    m.mart_transactions_60d = s.source_transactions_60d AS window_60d_pass,
    m.mart_transactions_90d = s.source_transactions_90d AS window_90d_pass,
    m.mart_purchase_lines_90d = s.source_purchase_lines_90d AS lines_90d_pass,
    m.min_snapshot_date = b.snapshot_date
        AND m.max_snapshot_date = b.snapshot_date AS anchor_pass,
    m.invalid_window_rows = 0 AS window_monotonicity_pass,
    DATE_DIFF(b.snapshot_date, s.observed_start_date, DAY) >= 89
        AS span_at_least_90_days_pass
FROM bounds AS b
CROSS JOIN source_transactions AS s
CROSS JOIN mart_metrics AS m
CROSS JOIN universe AS u;
