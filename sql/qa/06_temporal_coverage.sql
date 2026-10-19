-- Session 02 / Temporal profiling.
-- PURCHASE HISTORY END is not verified campaign T0. No causal cutoff claim.

-- Q1. Observed precommunication purchases: 118 calendar days, 5 touched months.
WITH typed AS (
    SELECT transaction_datetime,
           SAFE_CAST(NULLIF(TRIM(transaction_datetime), '') AS DATETIME) AS transaction_dt
    FROM `x5_raw.purchases`
)
SELECT COUNT(*) AS total_rows,
       COUNTIF(transaction_datetime IS NULL OR TRIM(transaction_datetime) = '') AS missing_dates,
       COUNTIF(transaction_datetime IS NOT NULL AND TRIM(transaction_datetime) != '' AND transaction_dt IS NULL) AS invalid_dates,
       MIN(transaction_dt) AS first_purchase,
       MAX(transaction_dt) AS last_purchase,
       COUNT(DISTINCT DATE(transaction_dt)) AS days_with_purchases,
       COUNT(DISTINCT DATE_TRUNC(DATE(transaction_dt), MONTH)) AS months_with_purchases
FROM typed;

-- Q2. First redemption beyond the observed purchase-history end.
WITH dates AS (
    SELECT client_id,
           DATE(SAFE_CAST(first_issue_date AS DATETIME)) AS issue_date,
           DATE(SAFE_CAST(first_redeem_date AS DATETIME)) AS redeem_date
    FROM `x5_raw.clients`
)
SELECT COUNT(*) AS total_clients,
       COUNTIF(issue_date > DATE '2019-03-18') AS issue_after_purchase_history,
       COUNTIF(redeem_date > DATE '2019-03-18') AS redeem_after_purchase_history,
       COUNTIF(redeem_date <= DATE '2019-03-18') AS redeem_within_or_before_history_end,
       COUNTIF(redeem_date IS NULL) AS missing_redeem,
       MIN(IF(redeem_date > DATE '2019-03-18', redeem_date, NULL)) AS first_later_redeem,
       MAX(redeem_date) AS last_redeem
FROM dates;
