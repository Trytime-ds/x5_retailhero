-- X5 RetailHero | Session 06 Part 2 | Gate E: joint 3x3 descriptive response
-- BigQuery GoogleSQL: run the WHOLE script in region US.
-- Design is POST-HOC EXPLORATORY relative to Gate C FDR families.
-- Descriptive comparison ONLY; not causal SMS uplift or targeting evidence.
-- No nine-cell hypothesis testing, CI or multiplicity claims.
-- Freeze frequency <=8, 9..18, >=19 and recency <=2, 3..7, >=8.
--
-- Output 1: 9 joint cells, arm counts, response rates, RD/RR, support flags.
-- Output 2: one QA row, independent source + Gate B/D reconciliation.
-- Do NOT proceed to Gates F/G unless gate_e_status = 'PASS_RECONCILED'.

CREATE TEMP TABLE s6_base AS
SELECT
    client_id, treatment_flg, target,
    transactions_90d, recency_days_at_history_end
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`;

-- Ensure no unmatched/duplicated IDs, invalid labels or broken historical
-- features. Dates/variable timing are NOT certified relative to SMS T0.
ASSERT (
    SELECT
        COUNT(*) = 200039
        AND COUNT(DISTINCT client_id) = 200039
        AND COUNTIF(
            client_id IS NULL
            OR treatment_flg IS NULL OR treatment_flg NOT IN (0,1)
            OR target IS NULL OR target NOT IN (0,1)
            OR transactions_90d IS NULL OR transactions_90d < 0
            OR recency_days_at_history_end IS NULL
            OR recency_days_at_history_end < 0
        ) = 0
    FROM s6_base
) AS 'STOP: Gate E base population/grain/labels changed';

CREATE TEMP TABLE s6_segmented AS
SELECT
    client_id, treatment_flg, target,
    CASE
        WHEN transactions_90d <= 8 THEN 'Low'
        WHEN transactions_90d <= 18 THEN 'Medium'
        ELSE 'High'
    END AS frequency_segment,
    CASE
        WHEN recency_days_at_history_end <= 2 THEN 'Recent'
        WHEN recency_days_at_history_end <= 7 THEN 'Intermediate'
        ELSE 'Less recent'
    END AS recency_segment
FROM s6_base;

-- These N/control/treatment values were fixed by outcome-blind Gate D.
CREATE TEMP TABLE s6_expected_joint AS
SELECT * FROM UNNEST([
    STRUCT('Low' AS frequency_segment, 'Recent' AS recency_segment,
           9944 AS expected_clients, 5001 AS expected_control_n,
           4943 AS expected_treatment_n, 1 AS frequency_sort, 1 AS recency_sort),
    STRUCT('Low','Intermediate',20753,10374,10379,1,2),
    STRUCT('Low','Less recent',39247,19721,19526,1,3),
    STRUCT('Medium','Recent',25301,12718,12583,2,1),
    STRUCT('Medium','Intermediate',23426,11780,11646,2,2),
    STRUCT('Medium','Less recent',19590,9783,9807,2,3),
    STRUCT('High','Recent',40820,20322,20498,3,1),
    STRUCT('High','Intermediate',15025,7470,7555,3,2),
    STRUCT('High','Less recent',5933,2889,3044,3,3)
]);

CREATE TEMP TABLE s6_joint_arm AS
SELECT
    frequency_segment, recency_segment, treatment_flg,
    COUNT(*) AS clients,
    COUNT(DISTINCT client_id) AS distinct_clients,
    COUNTIF(target=1) AS positive,
    COUNTIF(target=0) AS negative
FROM s6_segmented
GROUP BY 1,2,3;

CREATE TEMP TABLE s6_joint_pairs AS
SELECT
    e.frequency_segment, e.recency_segment,
    e.frequency_sort, e.recency_sort,
    e.expected_clients, e.expected_control_n, e.expected_treatment_n,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.clients, 0)),0) AS control_n,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.positive, 0)),0) AS control_positive,
    COALESCE(SUM(IF(c.treatment_flg = 0, c.negative, 0)),0) AS control_negative,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.clients, 0)),0) AS treatment_n,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.positive, 0)),0) AS treatment_positive,
    COALESCE(SUM(IF(c.treatment_flg = 1, c.negative, 0)),0) AS treatment_negative,
    COALESCE(SUM(c.clients),0) AS observed_clients
FROM s6_expected_joint AS e
LEFT JOIN s6_joint_arm AS c
  ON e.frequency_segment = c.frequency_segment
 AND e.recency_segment = c.recency_segment
GROUP BY 1,2,3,4,5,6,7;

-- Independently validate the source-defined training labels and membership.
CREATE TEMP TABLE s6_source AS
SELECT
    COUNT(*) AS n,
    COUNT(DISTINCT client_id) AS distinct_n,
    COUNTIF(treatment_flg=0) AS control_n,
    COUNTIF(treatment_flg=1) AS treatment_n,
    COUNTIF(treatment_flg=0 AND target=1) AS control_positive,
    COUNTIF(treatment_flg=0 AND target=0) AS control_negative,
    COUNTIF(treatment_flg=1 AND target=1) AS treatment_positive,
    COUNTIF(treatment_flg=1 AND target=0) AS treatment_negative,
    COUNTIF(
        client_id IS NULL OR treatment_flg IS NULL OR target IS NULL
        OR treatment_flg NOT IN (0,1) OR target NOT IN (0,1)
    ) AS invalid_rows
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`;

CREATE TEMP TABLE s6_source_mart_match AS
SELECT
    COUNTIF(
        t.client_id IS NULL
        OR t.treatment_flg != s.treatment_flg
        OR t.target != s.target
    ) AS source_to_mart_mismatches
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train` AS s
LEFT JOIN s6_base AS t USING (client_id);

-- Source-to-Gate-B marginal invariants, including observed positives.
CREATE TEMP TABLE s6_expected_marginal AS
SELECT * FROM UNNEST([
    STRUCT('frequency_90d' AS dimension,'Low' AS segment,
       35096 AS control_n,12559 AS control_positive,
       34848 AS treatment_n,14066 AS treatment_positive),
    STRUCT('frequency_90d','Medium',34281,21601,34036,22553),
    STRUCT('frequency_90d','High',30681,26203,31097,27020),
    STRUCT('recency_days','Recent',38041,29751,38024,30709),
    STRUCT('recency_days','Intermediate',29624,17708,29580,18720),
    STRUCT('recency_days','Less recent',32393,12904,32377,14210)
]);

CREATE TEMP TABLE s6_marginals AS
WITH unpivoted AS (
    SELECT
        'frequency_90d' AS dimension,
        frequency_segment AS segment,
        treatment_flg,target
    FROM s6_segmented
    UNION ALL
    SELECT
        'recency_days',recency_segment,treatment_flg,target
    FROM s6_segmented
)
SELECT
    dimension,segment,
    COUNTIF(treatment_flg=0) AS control_n,
    COUNTIF(treatment_flg=0 AND target=1) AS control_positive,
    COUNTIF(treatment_flg=1) AS treatment_n,
    COUNTIF(treatment_flg=1 AND target=1) AS treatment_positive
FROM unpivoted
GROUP BY 1,2;

CREATE TEMP TABLE s6_qa_marginal AS
SELECT
    COUNT(*) AS checked_marginals,
    COUNTIF(
        m.dimension IS NULL OR m.control_n != e.control_n
        OR m.control_positive != e.control_positive
        OR m.treatment_n != e.treatment_n
        OR m.treatment_positive != e.treatment_positive
    ) AS marginal_mismatches
FROM s6_expected_marginal AS e
LEFT JOIN s6_marginals AS m USING (dimension,segment);

CREATE TEMP TABLE s6_qa_joint AS
SELECT
    COUNT(*) AS expected_joint_cells,
    COUNTIF(
        observed_clients != expected_clients
        OR control_n != expected_control_n
        OR treatment_n != expected_treatment_n
        OR observed_clients != control_n + treatment_n
        OR control_n != control_positive + control_negative
        OR treatment_n != treatment_positive + treatment_negative
    ) AS joint_membership_mismatches,
    COUNTIF(
        control_n < 500 OR treatment_n < 500
        OR control_positive < 30 OR control_negative < 30
        OR treatment_positive < 30 OR treatment_negative < 30
    ) AS below_support_cells,
    SUM(observed_clients) AS total_clients,
    SUM(control_n) AS control_n,
    SUM(treatment_n) AS treatment_n,
    SUM(control_positive) AS control_positive,
    SUM(control_negative) AS control_negative,
    SUM(treatment_positive) AS treatment_positive,
    SUM(treatment_negative) AS treatment_negative
FROM s6_joint_pairs;

-- Output 1. All nine pre-existing joint cells, with source-defined
-- observed contrasts; no unplanned significance testing or causal labels.
SELECT
    frequency_segment,recency_segment,
    expected_clients,observed_clients,
    control_n,control_positive,control_negative,
    ROUND(100*SAFE_DIVIDE(control_positive,control_n),4)
        AS control_response_pct,
    treatment_n,treatment_positive,treatment_negative,
    ROUND(100*SAFE_DIVIDE(treatment_positive,treatment_n),4)
        AS treatment_response_pct,
    ROUND(
        100*(SAFE_DIVIDE(treatment_positive,treatment_n)
            -SAFE_DIVIDE(control_positive,control_n)),4
    ) AS observed_rd_pp,
    ROUND(
        SAFE_DIVIDE(
            SAFE_DIVIDE(treatment_positive,treatment_n),
            SAFE_DIVIDE(control_positive,control_n)
        ),6
    ) AS observed_rr,
    CASE
        WHEN observed_clients != expected_clients
          OR control_n != expected_control_n
          OR treatment_n != expected_treatment_n
            THEN 'STOP_MEMBERSHIP_MISMATCH'
        WHEN control_n < 500 OR treatment_n < 500
          OR control_positive < 30 OR control_negative < 30
          OR treatment_positive < 30 OR treatment_negative < 30
            THEN 'INSUFFICIENT_SUPPORT'
        ELSE 'PASS_SUPPORT'
    END AS cell_support_status
FROM s6_joint_pairs
ORDER BY frequency_sort,recency_sort;

-- Output 2. Treat only PASS_RECONCILED as sufficient to start Gate F.
SELECT
    q.expected_joint_cells,
    q.joint_membership_mismatches,
    q.below_support_cells,
    q.total_clients,
    q.control_n,q.treatment_n,
    q.control_positive,q.treatment_positive,
    q.control_negative,q.treatment_negative,
    m.checked_marginals,m.marginal_mismatches,
    s.n AS source_clients,s.distinct_n AS source_unique_clients,
    s.invalid_rows AS source_invalid_rows,
    x.source_to_mart_mismatches,
    CASE
        WHEN q.expected_joint_cells != 9
          OR q.joint_membership_mismatches != 0
          OR m.checked_marginals != 6 OR m.marginal_mismatches != 0
          OR s.invalid_rows != 0 OR x.source_to_mart_mismatches != 0
          OR s.n != 200039 OR s.distinct_n != 200039
          OR q.total_clients != s.n
          OR q.control_n != s.control_n
          OR q.treatment_n != s.treatment_n
          OR q.control_positive != s.control_positive
          OR q.control_negative != s.control_negative
          OR q.treatment_positive != s.treatment_positive
          OR q.treatment_negative != s.treatment_negative
          OR q.control_n != 100058 OR q.treatment_n != 99981
          OR q.control_positive != 60363
          OR q.treatment_positive != 63639
            THEN 'STOP_RECONCILIATION'
        WHEN q.below_support_cells > 0
            THEN 'REVIEW_INSUFFICIENT_SUPPORT'
        ELSE 'PASS_RECONCILED'
    END AS gate_e_status
FROM s6_qa_joint q
CROSS JOIN s6_qa_marginal m
CROSS JOIN s6_source s
CROSS JOIN s6_source_mart_match x;
