-- Session 02 / Client attributes and loyalty-date validity.
-- Age thresholds are diagnostic only; DO NOT delete clients based on them.

-- Q1. Full client profiling.
WITH typed AS (
    SELECT age AS raw_age,
           SAFE_CAST(age AS INT64) AS age_num,
           gender, first_issue_date, first_redeem_date,
           SAFE_CAST(first_issue_date AS DATETIME) AS issue_dt,
           SAFE_CAST(first_redeem_date AS DATETIME) AS redeem_dt
    FROM `x5_raw.clients`
)
SELECT COUNT(*) AS total_clients,
       COUNTIF(raw_age IS NULL OR TRIM(raw_age) = '') AS missing_age,
       COUNTIF(raw_age IS NOT NULL AND TRIM(raw_age) != '' AND age_num IS NULL) AS invalid_age,
       COUNTIF(age_num < 0) AS negative_age,
       COUNTIF(age_num BETWEEN 0 AND 17) AS under_18,
       COUNTIF(age_num > 100) AS over_100,
       MIN(age_num) AS min_age, MAX(age_num) AS max_age,
       COUNTIF(gender IS NULL OR TRIM(gender) = '') AS missing_gender,
       COUNT(DISTINCT gender) AS gender_categories,
       COUNTIF(issue_dt IS NULL) AS missing_or_invalid_issue,
       COUNTIF(redeem_dt IS NULL) AS missing_or_invalid_redeem,
       COUNTIF(redeem_dt < issue_dt) AS redeem_before_issue,
       MIN(issue_dt) AS min_issue_date, MAX(issue_dt) AS max_issue_date,
       MIN(redeem_dt) AS min_redeem_date, MAX(redeem_dt) AS max_redeem_date
FROM typed;

-- Q2. Disaggregate age anomalies and distinguish absent vs invalid redemptions.
WITH typed AS (
    SELECT SAFE_CAST(age AS INT64) AS age_num, TRIM(gender) AS gender,
           first_redeem_date,
           SAFE_CAST(first_redeem_date AS DATETIME) AS redeem_dt,
           SAFE_CAST(first_issue_date AS DATETIME) AS issue_dt
    FROM `x5_raw.clients`
)
SELECT gender, COUNT(*) AS clients,
       COUNTIF(age_num < 0) AS negative_age,
       COUNTIF(age_num = 0) AS age_zero,
       COUNTIF(age_num BETWEEN 1 AND 17) AS age_1_17,
       COUNTIF(age_num > 100) AS age_gt_100,
       COUNTIF(first_redeem_date IS NULL OR TRIM(first_redeem_date) = '') AS missing_redeem,
       COUNTIF(first_redeem_date IS NOT NULL AND TRIM(first_redeem_date) != '' AND redeem_dt IS NULL) AS invalid_redeem,
       COUNTIF(redeem_dt < issue_dt) AS redeem_before_issue
FROM typed
GROUP BY gender
ORDER BY clients DESC;
