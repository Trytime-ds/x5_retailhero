-- X5 RetailHero | Session 06 Part 2 | Gate F: composition/scale sensitivity
-- GoogleSQL / BigQuery US; run entire multi-statement script.
-- Gate E (owner-run) 9/9 PASS_SUPPORT and PASS_RECONCILED.
-- NO causal effect: SMS exposure, T0, randomization/outcome timing unverified.
-- Observed joint cutpoints frozen; no rebinning, new 3x3 p-values or CI.
--
-- Common-weight DIRECT STANDARDIZATION is descriptive arithmetic:
-- in each scope, weight each joint cell by its POOLED client share
-- (control+treatment); apply the SAME weight to both arms' cell rates.
-- It does not solve unmeasured confounding, temporal leakage or selection.
--
-- Result 1: overall + 3 frequency + 3 recency groups (7 non-additive rows):
-- raw and pooled-cell-standardized response/RD/RR, composition shift.
-- Result 2: 9 joint-cell baseline response, absolute RD, RR and
--           mathematical response headroom; NO additional tests.
-- Result 3: audit gates: frozen nine-cell counts, source arm parity,
--           7 scopes, cross-scope coverage, expected raw marginal RDs.
-- A PASS here documents arithmetic sensitivity, NOT identification.

CREATE TEMP TABLE s6_base AS
SELECT
    client_id, treatment_flg, target,
    transactions_90d, recency_days_at_history_end
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.mart_experiment_analysis`;

ASSERT (
    SELECT COUNT(*) = 200039
       AND COUNT(DISTINCT client_id) = 200039
       AND COUNTIF(
           client_id IS NULL OR treatment_flg IS NULL
           OR treatment_flg NOT IN (0,1)
           OR target IS NULL OR target NOT IN (0,1)
           OR transactions_90d IS NULL OR transactions_90d < 0
           OR recency_days_at_history_end IS NULL
           OR recency_days_at_history_end < 0
       ) = 0
    FROM s6_base
) AS 'STOP: Gate F source grain/labels/features failed';

CREATE TEMP TABLE s6_joint AS
SELECT
    CASE WHEN transactions_90d <= 8 THEN 'Low'
         WHEN transactions_90d <= 18 THEN 'Medium'
         ELSE 'High' END AS frequency_segment,
    CASE WHEN recency_days_at_history_end <= 2 THEN 'Recent'
         WHEN recency_days_at_history_end <= 7 THEN 'Intermediate'
         ELSE 'Less recent' END AS recency_segment,
    treatment_flg, target
FROM s6_base;

CREATE TEMP TABLE s6_expected AS
SELECT * FROM UNNEST([
  STRUCT('Low' AS frequency_segment,'Recent' AS recency_segment,
         9944 AS expected_n,5001 AS expected_control,4943 AS expected_treatment),
  STRUCT('Low','Intermediate',20753,10374,10379),
  STRUCT('Low','Less recent',39247,19721,19526),
  STRUCT('Medium','Recent',25301,12718,12583),
  STRUCT('Medium','Intermediate',23426,11780,11646),
  STRUCT('Medium','Less recent',19590,9783,9807),
  STRUCT('High','Recent',40820,20322,20498),
  STRUCT('High','Intermediate',15025,7470,7555),
  STRUCT('High','Less recent',5933,2889,3044)
]);

CREATE TEMP TABLE s6_joint_counts AS
SELECT frequency_segment,recency_segment,
    COUNT(*) AS n,
    COUNTIF(treatment_flg=0) AS n0,
    COUNTIF(treatment_flg=0 AND target=1) AS y0,
    COUNTIF(treatment_flg=0 AND target=0) AS neg0,
    COUNTIF(treatment_flg=1) AS n1,
    COUNTIF(treatment_flg=1 AND target=1) AS y1,
    COUNTIF(treatment_flg=1 AND target=0) AS neg1
FROM s6_joint
GROUP BY 1,2;

ASSERT (
    SELECT COUNT(*) = 9 AND COUNTIF(
         c.frequency_segment IS NULL
         OR c.n != e.expected_n
         OR c.n0 != e.expected_control
         OR c.n1 != e.expected_treatment
         OR c.n0 < 500 OR c.n1 < 500
         OR c.y0 < 30 OR c.y1 < 30
         OR c.neg0 < 30 OR c.neg1 < 30
    ) = 0
    FROM s6_expected AS e
    LEFT JOIN s6_joint_counts AS c
      USING (frequency_segment,recency_segment)
) AS 'STOP: frozen joint membership or support no longer passes';

CREATE TEMP TABLE s6_source AS
SELECT
    COUNT(*) AS n,
    COUNT(DISTINCT client_id) AS unique_clients,
    COUNTIF(treatment_flg=0) AS n0,
    COUNTIF(treatment_flg=1) AS n1,
    COUNTIF(treatment_flg=0 AND target=1) AS y0,
    COUNTIF(treatment_flg=1 AND target=1) AS y1,
    COUNTIF(treatment_flg=0 AND target=0) AS neg0,
    COUNTIF(treatment_flg=1 AND target=0) AS neg1,
    COUNTIF(client_id IS NULL OR treatment_flg NOT IN (0,1)
       OR target NOT IN (0,1) OR treatment_flg IS NULL
       OR target IS NULL) AS invalid_rows
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`;

ASSERT (
    SELECT
      s.n = 200039 AND s.unique_clients = 200039
      AND s.n0 = 100058 AND s.n1 = 99981
      AND s.y0 = 60363 AND s.y1 = 63639
      AND s.neg0 = 39695 AND s.neg1 = 36342
      AND s.invalid_rows = 0
      AND SUM(j.n) = s.n
      AND SUM(j.n0) = s.n0
      AND SUM(j.n1) = s.n1
      AND SUM(j.y0) = s.y0
      AND SUM(j.y1) = s.y1
    FROM s6_source AS s CROSS JOIN s6_joint_counts AS j
    GROUP BY s.n,s.unique_clients,s.n0,s.n1,s.y0,s.y1,
             s.neg0,s.neg1,s.invalid_rows
) AS 'STOP: joint rows do not reconcile with original training source';

CREATE TEMP TABLE s6_cell_rates AS
SELECT
    *,
    SAFE_DIVIDE(y0,n0) AS p0,
    SAFE_DIVIDE(y1,n1) AS p1,
    SAFE_DIVIDE(n0,n0+n1) AS control_mix_within_cell,
    SAFE_DIVIDE(n1,n0+n1) AS treatment_mix_within_cell
FROM s6_joint_counts;

-- Alternative scopes of the SAME customers. Never sum across scopes.
CREATE TEMP TABLE s6_scope_cells AS
SELECT
    'overall' AS analysis_scope,
    'All clients' AS analysis_segment,
    * FROM s6_cell_rates
UNION ALL
SELECT 'frequency','frequency: '||frequency_segment,* FROM s6_cell_rates
UNION ALL
SELECT 'recency','recency: '||recency_segment,* FROM s6_cell_rates;

CREATE TEMP TABLE s6_scoped_weights AS
SELECT
    *,
    SAFE_DIVIDE(
        n, SUM(n) OVER (PARTITION BY analysis_scope,analysis_segment)
    ) AS common_pooled_weight
FROM s6_scope_cells;

CREATE TEMP TABLE s6_summary AS
WITH aggregation AS (
    SELECT
        analysis_scope, analysis_segment,
        COUNT(*) AS included_joint_cells,
        SUM(n) AS clients,
        SUM(n0) AS control_n, SUM(y0) AS control_positive,
        SUM(n1) AS treatment_n, SUM(y1) AS treatment_positive,
        SUM(common_pooled_weight) AS weight_sum,
        SUM(common_pooled_weight * p0) AS standardized_p0,
        SUM(common_pooled_weight * p1) AS standardized_p1
    FROM s6_scoped_weights
    GROUP BY 1,2
)
SELECT
    *,
    SAFE_DIVIDE(control_positive,control_n) AS raw_p0,
    SAFE_DIVIDE(treatment_positive,treatment_n) AS raw_p1
FROM aggregation;

-- Output 1: DIFFERENT analytical scopes share clients; choose one scope
-- for an additive population total in downstream reporting.
SELECT
    analysis_scope, analysis_segment,
    included_joint_cells,clients,control_n,treatment_n,
    control_positive,treatment_positive,
    ROUND(weight_sum,8) AS common_weight_sum,
    ROUND(100*raw_p0,4) AS raw_control_response_pct,
    ROUND(100*raw_p1,4) AS raw_treatment_response_pct,
    ROUND(100*(raw_p1-raw_p0),4) AS raw_observed_rd_pp,
    ROUND(SAFE_DIVIDE(raw_p1,raw_p0),6) AS raw_observed_rr,
    ROUND(100*standardized_p0,4) AS pooled_std_control_response_pct,
    ROUND(100*standardized_p1,4) AS pooled_std_treatment_response_pct,
    ROUND(100*(standardized_p1-standardized_p0),4)
        AS pooled_std_rd_pp,
    ROUND(SAFE_DIVIDE(standardized_p1,standardized_p0),6)
        AS pooled_std_rr,
    ROUND(100*((standardized_p1-standardized_p0)-(raw_p1-raw_p0)),4)
        AS std_minus_raw_rd_pp,
    'DESCRIPTIVE_NOT_CAUSAL' AS interpretation
FROM s6_summary
ORDER BY
  CASE analysis_scope WHEN 'overall' THEN 1
    WHEN 'frequency' THEN 2 ELSE 3 END,
  CASE analysis_segment
    WHEN 'All clients' THEN 0
    WHEN 'frequency: Low' THEN 1 WHEN 'recency: Recent' THEN 1
    WHEN 'frequency: Medium' THEN 2 WHEN 'recency: Intermediate' THEN 2
    ELSE 3 END;

-- Output 2: the response ceiling is mechanical, not evidence of a
-- specific SMS mechanism. Maximum upward absolute RD from baseline
-- control response is 100*(1-p0) pp, not an expected effect size.
SELECT frequency_segment,recency_segment,n AS clients,n0 AS control_n,
       n1 AS treatment_n,
       ROUND(100*p0,4) AS control_response_pct,
       ROUND(100*p1,4) AS treatment_response_pct,
       ROUND(100*(p1-p0),4) AS observed_rd_pp,
       ROUND(SAFE_DIVIDE(p1,p0),6) AS observed_rr,
       ROUND(100*(1-p0),4) AS mathematical_upward_headroom_pp,
       ROUND(100*SAFE_DIVIDE(p1-p0,1-p0),4)
           AS observed_gap_as_pct_of_headroom,
       'DESCRIPTIVE_CEILING_DIAGNOSTIC' AS interpretation
FROM s6_cell_rates
ORDER BY
 CASE frequency_segment WHEN 'Low' THEN 1
     WHEN 'Medium' THEN 2 ELSE 3 END,
 CASE recency_segment WHEN 'Recent' THEN 1
     WHEN 'Intermediate' THEN 2 ELSE 3 END;

-- Three scopes represent alternative representations, NOT independent
-- populations. Each separately must reconcile exactly to train source.
CREATE TEMP TABLE s6_qa_scopes AS
SELECT
    analysis_scope,
    COUNT(*) AS groups_in_scope,
    SUM(clients) AS client_total,
    SUM(control_n) AS control_total,
    SUM(treatment_n) AS treatment_total,
    SUM(control_positive) AS control_positive_total,
    SUM(treatment_positive) AS treatment_positive_total,
    COUNTIF(ABS(weight_sum-1.0)>0.00000001) AS bad_weight_groups
FROM s6_summary
GROUP BY 1;

-- Independent published Gate B raw expected rates, based on integer counts.
CREATE TEMP TABLE s6_expected_raw AS
SELECT * FROM UNNEST([
 STRUCT('overall' AS analysis_scope,'All clients' AS analysis_segment,
        100058 AS n0,60363 AS y0,99981 AS n1,63639 AS y1),
 STRUCT('frequency','frequency: Low',35096,12559,34848,14066),
 STRUCT('frequency','frequency: Medium',34281,21601,34036,22553),
 STRUCT('frequency','frequency: High',30681,26203,31097,27020),
 STRUCT('recency','recency: Recent',38041,29751,38024,30709),
 STRUCT('recency','recency: Intermediate',29624,17708,29580,18720),
 STRUCT('recency','recency: Less recent',32393,12904,32377,14210)
]);

CREATE TEMP TABLE s6_qa_raw AS
SELECT COUNT(*) AS expected_groups,
    COUNTIF(a.analysis_scope IS NULL OR a.control_n!=e.n0
       OR a.control_positive!=e.y0 OR a.treatment_n!=e.n1
       OR a.treatment_positive!=e.y1) AS raw_marginal_mismatches
FROM s6_expected_raw AS e
LEFT JOIN s6_summary AS a USING(analysis_scope,analysis_segment);

-- Output 3: only PASS permits reporting-layer design.
SELECT
    COUNT(*) AS scopes,
    SUM(groups_in_scope) AS summary_rows,
    COUNTIF(groups_in_scope != CASE analysis_scope
      WHEN 'overall' THEN 1 ELSE 3 END) AS bad_scope_group_counts,
    COUNTIF(client_total != 200039 OR control_total != 100058
      OR treatment_total != 99981
      OR control_positive_total != 60363
      OR treatment_positive_total != 63639) AS bad_scope_reconciliations,
    SUM(bad_weight_groups) AS bad_weight_groups,
    MAX(q.expected_groups) AS expected_raw_groups,
    MAX(q.raw_marginal_mismatches) AS raw_marginal_mismatches,
    CASE WHEN COUNT(*)=3 AND SUM(groups_in_scope)=7
      AND COUNTIF(groups_in_scope != CASE analysis_scope
        WHEN 'overall' THEN 1 ELSE 3 END)=0
      AND COUNTIF(client_total != 200039 OR control_total != 100058
        OR treatment_total != 99981
        OR control_positive_total != 60363
        OR treatment_positive_total != 63639)=0
      AND SUM(bad_weight_groups)=0
      AND MAX(q.expected_groups)=7
      AND MAX(q.raw_marginal_mismatches)=0
      THEN 'PASS_RECONCILED'
      ELSE 'STOP_RECONCILIATION'
    END AS gate_f_status
FROM s6_qa_scopes CROSS JOIN s6_qa_raw AS q;
