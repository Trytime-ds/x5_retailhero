-- Session 02 / Preliminary experiment balance.
-- Observed balance does NOT establish randomized assignment.
-- History end 2019-03-18 is only an exploratory reference, not verified T0.

-- Q1. Gender mix within each experiment arm.
WITH demographic_balance AS (
    SELECT t.treatment_flg, c.gender, COUNT(*) AS clients
    FROM `x5_raw.uplift_train` AS t
    JOIN `x5_raw.clients` AS c USING (client_id)
    GROUP BY 1,2
)
SELECT treatment_flg, gender, clients,
       ROUND(100 * SAFE_DIVIDE(clients, SUM(clients) OVER (PARTITION BY treatment_flg)), 2) AS pct_within_group
FROM demographic_balance
ORDER BY treatment_flg, gender;

-- Q2. Frequency / recency comparisons.
WITH history AS (
    SELECT client_id,
           COUNT(DISTINCT transaction_id) AS transactions,
           MAX(DATE(SAFE_CAST(transaction_datetime AS DATETIME))) AS last_purchase_date
    FROM `x5_raw.purchases`
    GROUP BY client_id
), exp AS (
    SELECT t.treatment_flg,
           COALESCE(h.transactions, 0) AS transactions,
           DATE_DIFF(DATE '2019-03-18', h.last_purchase_date, DAY) AS recency_days
    FROM `x5_raw.uplift_train` AS t
    LEFT JOIN history AS h USING (client_id)
)
SELECT treatment_flg, COUNT(*) AS clients,
       COUNTIF(transactions = 0) AS clients_without_purchases,
       ROUND(100 * SAFE_DIVIDE(COUNTIF(transactions = 0), COUNT(*)), 2) AS pct_without_purchases,
       ROUND(AVG(transactions), 2) AS avg_transactions,
       APPROX_QUANTILES(transactions, 100)[OFFSET(50)] AS median_transactions,
       APPROX_QUANTILES(transactions, 100)[OFFSET(90)] AS p90_transactions,
       ROUND(AVG(recency_days), 2) AS avg_recency_days
FROM exp GROUP BY treatment_flg ORDER BY treatment_flg;

-- Q3. Standardized mean differences (SMD) for history features.
WITH history AS (
    SELECT client_id,
           COUNT(DISTINCT transaction_id) AS transactions,
           MAX(DATE(SAFE_CAST(transaction_datetime AS DATETIME))) AS last_purchase
    FROM `x5_raw.purchases`
    GROUP BY client_id
), exp AS (
    SELECT t.treatment_flg,
           CAST(COALESCE(h.transactions, 0) AS FLOAT64) AS transactions,
           CAST(DATE_DIFF(DATE '2019-03-18', h.last_purchase, DAY) AS FLOAT64) AS recency_days
    FROM `x5_raw.uplift_train` AS t
    LEFT JOIN history AS h USING (client_id)
), stats AS (
    SELECT treatment_flg,
           AVG(transactions) AS avg_tx, STDDEV_POP(transactions) AS sd_tx,
           AVG(recency_days) AS avg_recency, STDDEV_POP(recency_days) AS sd_recency
    FROM exp GROUP BY treatment_flg
), comparison AS (
    SELECT t.avg_tx AS tx_t, c.avg_tx AS tx_c, t.sd_tx AS sd_tx_t, c.sd_tx AS sd_tx_c,
           t.avg_recency AS recency_t, c.avg_recency AS recency_c,
           t.sd_recency AS sd_recency_t, c.sd_recency AS sd_recency_c
    FROM stats AS t CROSS JOIN stats AS c
    WHERE t.treatment_flg = '1' AND c.treatment_flg = '0'
)
SELECT 'transactions' AS metric,
       ROUND(tx_t, 2) AS treatment_mean,
       ROUND(tx_c, 2) AS control_mean,
       ROUND(SAFE_DIVIDE(tx_t - tx_c, SQRT((POW(sd_tx_t, 2) + POW(sd_tx_c, 2)) / 2)), 4) AS smd
FROM comparison
UNION ALL
SELECT 'recency_days', ROUND(recency_t, 2), ROUND(recency_c, 2),
       ROUND(SAFE_DIVIDE(recency_t - recency_c, SQRT((POW(sd_recency_t, 2) + POW(sd_recency_c, 2)) / 2)), 4)
FROM comparison;
