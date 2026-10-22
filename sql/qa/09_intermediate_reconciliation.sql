-- Session 4 / BigQuery US: execute AFTER dbt builds int_transactions.
-- Source scans may have processing cost. Inspect bytes billed first.
WITH source_metrics AS (
    SELECT
        COUNT(*) AS source_lines,
        COUNTIF(is_zero_quantity) AS source_zero_qty_lines,
        COUNTIF(is_quantity_above_review_threshold) AS source_extreme_qty_lines
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_purchases`
),
ticket_metrics AS (
    SELECT
        COUNT(*) AS tickets,
        SUM(line_count) AS recovered_lines,
        SUM(zero_quantity_line_count) AS recovered_zero_qty_lines,
        SUM(extreme_quantity_line_count) AS recovered_extreme_qty_lines,
        COUNTIF(has_store_inconsistency) AS store_inconsistencies,
        COUNTIF(has_datetime_inconsistency) AS datetime_inconsistencies,
        COUNTIF(has_purchase_sum_inconsistency) AS purchase_sum_inconsistencies
    FROM `x5-retailhero-analytics-2026.x5_dbt_dev.int_transactions`
)
SELECT
    t.*,
    s.*,
    t.tickets = 8045229 AS historical_ticket_count_pass,
    s.source_lines = 45786568 AS historical_purchase_line_count_pass,
    t.recovered_lines = s.source_lines AS line_reconciliation_pass,
    t.recovered_zero_qty_lines = s.source_zero_qty_lines AS zero_quantity_reconciliation_pass,
    t.recovered_extreme_qty_lines = s.source_extreme_qty_lines AS extreme_quantity_reconciliation_pass,
    t.store_inconsistencies = 0
        AND t.datetime_inconsistencies = 0
        AND t.purchase_sum_inconsistencies = 0 AS ticket_attributes_consistent_pass
FROM ticket_metrics AS t
CROSS JOIN source_metrics AS s;
