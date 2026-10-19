-- Session 02 / FK coverage and join cardinality.
-- Requires verified unique client/product IDs. Expected joined_rows=45,786,568;
-- observed orphan counts=0 and no additional rows.
SELECT
    COUNT(*) AS joined_rows,
    COUNTIF(c.client_id IS NULL) AS orphan_client_rows,
    COUNT(DISTINCT IF(c.client_id IS NULL, pu.client_id, NULL)) AS orphan_client_ids,
    COUNTIF(pr.product_id IS NULL) AS orphan_product_rows,
    COUNT(DISTINCT IF(pr.product_id IS NULL, pu.product_id, NULL)) AS orphan_product_ids,
    COUNTIF(c.client_id IS NULL AND pr.product_id IS NULL) AS orphan_both_rows
FROM `x5_raw.purchases` AS pu
LEFT JOIN `x5_raw.clients` AS c ON pu.client_id = c.client_id
LEFT JOIN `x5_raw.products` AS pr ON pu.product_id = pr.product_id;
