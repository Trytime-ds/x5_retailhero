-- X5 RetailHero | Session 06 Gate G: independent reporting VIEW QA.
-- Run entire BigQuery GoogleSQL script in US AFTER owner dbt run/test.
-- No write operations here. Expected labels/counts frozen from owner-run
-- Gates B, E, F on 2026-11-05. Outcome is NOT verified causal SMS effect.
-- Output 1: four alternative, non-additive scope source reconciliations.
-- Output 2: one full independent Gate G status.
-- Do not sum clients across scopes (4 views of same 200,039 people).

CREATE TEMP TABLE s6_rpt AS
SELECT *
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.rpt_experiment_response_segments`;

CREATE TEMP TABLE s6_src AS
SELECT
  COUNT(*) AS clients,
  COUNT(DISTINCT client_id) AS distinct_clients,
  COUNTIF(treatment_flg=0) AS control_n,
  COUNTIF(treatment_flg=1) AS treatment_n,
  COUNTIF(treatment_flg=0 AND target=1) AS control_positive,
  COUNTIF(treatment_flg=0 AND target=0) AS control_negative,
  COUNTIF(treatment_flg=1 AND target=1) AS treatment_positive,
  COUNTIF(treatment_flg=1 AND target=0) AS treatment_negative,
  COUNTIF(client_id IS NULL OR treatment_flg IS NULL OR target IS NULL
      OR treatment_flg NOT IN (0,1) OR target NOT IN (0,1))
     AS invalid_source_rows
FROM `x5-retailhero-analytics-2026.x5_dbt_dev.stg_uplift_train`;

CREATE TEMP TABLE s6_expected AS
SELECT * FROM UNNEST([
  STRUCT('overall|-|-' AS analysis_key, 'overall' AS analysis_scope,
     200039 AS clients,100058 AS control_n,60363 AS control_positive,
     99981 AS treatment_n,63639 AS treatment_positive,3.2112 AS std_rd_pp),
  STRUCT('frequency|Low|-','frequency',69944,35096,12559,34848,14066,4.5723),
  STRUCT('frequency|Medium|-','frequency',68317,34281,21601,34036,22553,3.2905),
  STRUCT('frequency|High|-','frequency',61778,30681,26203,31097,27020,1.5824),
  STRUCT('recency|-|Recent','recency',76065,38041,29751,38024,30709,2.4352),
  STRUCT('recency|-|Intermediate','recency',59204,29624,17708,29580,18720,3.4709),
  STRUCT('recency|-|Less recent','recency',64770,32393,12904,32377,14210,3.8851),
  STRUCT('joint|Low|Recent','joint',9944,5001,2539,4943,2728,CAST(NULL AS FLOAT64)),
  STRUCT('joint|Low|Intermediate','joint',20753,10374,4050,10379,4557,NULL),
  STRUCT('joint|Low|Less recent','joint',39247,19721,5970,19526,6781,NULL),
  STRUCT('joint|Medium|Recent','joint',25301,12718,8916,12583,9264,NULL),
  STRUCT('joint|Medium|Intermediate','joint',23426,11780,7537,11646,7835,NULL),
  STRUCT('joint|Medium|Less recent','joint',19590,9783,5148,9807,5454,NULL),
  STRUCT('joint|High|Recent','joint',40820,20322,18296,20498,18717,NULL),
  STRUCT('joint|High|Intermediate','joint',15025,7470,6121,7555,6328,NULL),
  STRUCT('joint|High|Less recent','joint',5933,2889,1786,3044,1975,NULL)
]);

CREATE TEMP TABLE s6_scope_totals AS
SELECT
  analysis_scope,
  COUNT(*) AS reporting_rows,
  SUM(clients) AS scoped_clients,
  SUM(control_n) AS scoped_control,
  SUM(treatment_n) AS scoped_treatment,
  SUM(control_positive) AS scoped_control_positive,
  SUM(control_negative) AS scoped_control_negative,
  SUM(treatment_positive) AS scoped_treatment_positive,
  SUM(treatment_negative) AS scoped_treatment_negative
FROM s6_rpt GROUP BY 1;

CREATE TEMP TABLE s6_expected_scopes AS
SELECT * FROM UNNEST([
  STRUCT('overall' AS analysis_scope,1 AS expected_rows),
  STRUCT('frequency',3),
  STRUCT('recency',3),
  STRUCT('joint',9)
]);

CREATE TEMP TABLE s6_scoped_checks AS
SELECT
  e.analysis_scope,
  e.expected_rows,
  r.reporting_rows,
  r.scoped_clients,
  r.scoped_control,
  r.scoped_treatment,
  r.scoped_control_positive,
  r.scoped_treatment_positive,
  CASE WHEN r.reporting_rows IS NULL THEN 'STOP_MISSING_SCOPE'
     WHEN r.reporting_rows!=e.expected_rows
       OR r.scoped_clients != s.clients
       OR r.scoped_control != s.control_n
       OR r.scoped_treatment != s.treatment_n
       OR r.scoped_control_positive != s.control_positive
       OR r.scoped_control_negative != s.control_negative
       OR r.scoped_treatment_positive != s.treatment_positive
       OR r.scoped_treatment_negative != s.treatment_negative
       THEN 'STOP_SCOPE_TOTALS'
     ELSE 'PASS_RECONCILED' END AS scope_status
FROM s6_expected_scopes AS e
LEFT JOIN s6_scope_totals AS r USING(analysis_scope)
CROSS JOIN s6_src AS s;

CREATE TEMP TABLE s6_expected_qa AS
SELECT
   COUNT(*) AS expected_keys,
   COUNTIF(r.analysis_key IS NULL OR r.analysis_scope!=e.analysis_scope
     OR r.clients!=e.clients
     OR r.control_n!=e.control_n OR r.control_positive!=e.control_positive
     OR r.control_negative!=e.control_n-e.control_positive
     OR r.treatment_n!=e.treatment_n
     OR r.treatment_positive!=e.treatment_positive
     OR r.treatment_negative!=e.treatment_n-e.treatment_positive
     OR r.support_status!='PASS_SUPPORT'
     OR r.history_end_date!=DATE '2019-03-18'
     OR (e.std_rd_pp IS NOT NULL AND
        (r.pooled_std_rd_pp IS NULL
         OR ABS(r.pooled_std_rd_pp-e.std_rd_pp)>0.0002))
   ) AS missing_or_mismatched_expected_keys
FROM s6_expected AS e
LEFT JOIN s6_rpt AS r USING(analysis_key);

CREATE TEMP TABLE s6_metric_qa AS
SELECT
  COUNT(*) AS actual_rows,
  COUNT(DISTINCT analysis_key) AS distinct_keys,
  COUNTIF(e.analysis_key IS NULL) AS unexpected_keys,
  COUNTIF(r.clients!=r.control_n+r.treatment_n
     OR r.control_n!=r.control_positive+r.control_negative
     OR r.treatment_n!=r.treatment_positive+r.treatment_negative
     OR r.control_response_pct IS NULL
     OR r.treatment_response_pct IS NULL OR r.observed_rd_pp IS NULL
     OR r.observed_rr IS NULL
     OR ABS(r.control_response_pct
       -100*SAFE_DIVIDE(r.control_positive,r.control_n))>1e-8
     OR ABS(r.treatment_response_pct
       -100*SAFE_DIVIDE(r.treatment_positive,r.treatment_n))>1e-8
     OR ABS(r.observed_rd_pp
       -(r.treatment_response_pct-r.control_response_pct))>1e-8
     OR ABS(r.observed_rr-SAFE_DIVIDE(
        SAFE_DIVIDE(r.treatment_positive,r.treatment_n),
        SAFE_DIVIDE(r.control_positive,r.control_n)))>1e-8
  ) AS bad_rates_or_counts,
  COUNTIF(
     r.analysis_scope='joint' AND (
       r.rd_ci95_lower_pp IS NOT NULL OR r.rd_ci95_upper_pp IS NOT NULL
       OR r.rr_ci95_lower IS NOT NULL OR r.rr_ci95_upper IS NOT NULL
       OR r.pooled_std_rd_pp IS NOT NULL OR r.pooled_std_rr IS NOT NULL
       OR r.pooled_std_control_response_pct IS NOT NULL
       OR r.pooled_std_treatment_response_pct IS NOT NULL
       OR r.std_minus_raw_rd_pp IS NOT NULL
       OR r.ci_method IS NOT NULL
       OR r.inference_scope!='POST_HOC_DESCRIPTIVE_ONLY'
     )
  ) AS joint_rows_with_inference_or_std,
  COUNTIF(
     r.analysis_scope!='joint' AND (
       r.rd_ci95_lower_pp IS NULL OR r.rd_ci95_upper_pp IS NULL
       OR r.rr_ci95_lower IS NULL OR r.rr_ci95_upper IS NULL
       OR r.pooled_std_rd_pp IS NULL OR r.pooled_std_rr IS NULL
       OR r.std_minus_raw_rd_pp IS NULL
       OR r.pooled_std_control_response_pct IS NULL
       OR r.pooled_std_treatment_response_pct IS NULL
       OR r.ci_method!='WALD_RD_AND_LOG_KATZ_RR_UNADJUSTED_95'
       OR r.inference_scope!='MARGINAL_DESCRIPTIVE_WITH_UNADJUSTED_CI'
     )
  ) AS missing_nonjoint_inference_or_std,
  COUNTIF(r.metric_semantics!='OBSERVED_SOURCE_DEFINED_RESPONSE_NOT_CAUSAL'
     OR r.causal_eligibility!='T0_ASSIGNMENT_DELIVERY_OUTCOME_WINDOW_NOT_VERIFIED'
     OR r.support_status!='PASS_SUPPORT') AS bad_semantic_or_support_flags
FROM s6_rpt AS r
LEFT JOIN s6_expected AS e USING(analysis_key);

-- Result set 1: four independent scope reconciliations.
SELECT * FROM s6_scoped_checks ORDER BY
  CASE analysis_scope WHEN 'overall' THEN 1 WHEN 'frequency' THEN 2
    WHEN 'recency' THEN 3 ELSE 4 END;

-- Result set 2: inspect all diagnostic counts before claiming PASS.
SELECT
  (SELECT COUNT(*) FROM s6_scoped_checks) AS scopes,
  (SELECT COUNTIF(scope_status!='PASS_RECONCILED')
     FROM s6_scoped_checks) AS failing_scopes,
  q.expected_keys, q.missing_or_mismatched_expected_keys,
  m.actual_rows,m.distinct_keys,m.unexpected_keys,
  m.bad_rates_or_counts,m.joint_rows_with_inference_or_std,
  m.missing_nonjoint_inference_or_std,m.bad_semantic_or_support_flags,
  s.clients AS source_clients,s.distinct_clients AS source_unique_clients,
  s.control_n AS source_control_n,s.treatment_n AS source_treatment_n,
  s.invalid_source_rows,
  CASE
    WHEN (SELECT COUNT(*) FROM s6_scoped_checks)!=4
      OR (SELECT COUNTIF(scope_status!='PASS_RECONCILED')
            FROM s6_scoped_checks)!=0
      OR s.clients!=200039 OR s.distinct_clients!=200039
      OR s.control_n!=100058 OR s.treatment_n!=99981
      OR s.control_positive!=60363 OR s.treatment_positive!=63639
      OR s.control_negative!=39695 OR s.treatment_negative!=36342
      OR s.invalid_source_rows!=0
      OR q.expected_keys!=16 OR q.missing_or_mismatched_expected_keys!=0
      OR m.actual_rows!=16 OR m.distinct_keys!=16 OR m.unexpected_keys!=0
      OR m.bad_rates_or_counts!=0
      OR m.joint_rows_with_inference_or_std!=0
      OR m.missing_nonjoint_inference_or_std!=0
      OR m.bad_semantic_or_support_flags!=0
      THEN 'STOP_RECONCILIATION'
    ELSE 'PASS_RECONCILED'
  END AS gate_g_status
FROM s6_expected_qa AS q
CROSS JOIN s6_metric_qa AS m
CROSS JOIN s6_src AS s;
