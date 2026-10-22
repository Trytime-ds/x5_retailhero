-- Guardrails on derived counts; no assumptions about quantity units.
SELECT client_id, transaction_id
FROM {{ ref('int_transactions') }}
WHERE line_count < 1
   OR distinct_product_count < 1
   OR distinct_product_count > line_count
   OR zero_quantity_line_count < 0
   OR extreme_quantity_line_count < 0
   OR zero_quantity_line_count > line_count
   OR extreme_quantity_line_count > line_count
