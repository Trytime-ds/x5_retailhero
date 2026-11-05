-- dbt singular test: returns ZERO rows only when Gate G reporting view
-- reproduces all owner-run source, Gate B/E/F counts and semantics.
-- Frozen 2026-11-05 source evidence; FAIL on source version drift.
-- Every scope represents SAME train clients; do not add scopes together.

WITH rpt AS (
  SELECT * FROM {{ ref('rpt_experiment_response_segments') }}
), expected AS (
  SELECT * FROM UNNEST([
    STRUCT('overall|-|-' AS analysis_key, 'overall' AS scope,
      200039 AS clients,100058 AS n0,60363 AS y0,
      99981 AS n1,63639 AS y1,3.2112 AS std_rd_pp),
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
  ])
), source AS (
  SELECT
    COUNT(*) AS n,COUNT(DISTINCT client_id) AS unique_clients,
    COUNTIF(treatment_flg=0) AS n0,
    COUNTIF(treatment_flg=1) AS n1,
    COUNTIF(treatment_flg=0 AND target=1) AS y0,
    COUNTIF(treatment_flg=1 AND target=1) AS y1
  FROM {{ ref('stg_uplift_train') }}
), scope_totals AS (
  SELECT analysis_scope,
    COUNT(*) AS scope_rows,
    SUM(clients) AS clients,
    SUM(control_n) AS n0,
    SUM(treatment_n) AS n1,
    SUM(control_positive) AS y0,
    SUM(treatment_positive) AS y1
  FROM rpt
  GROUP BY analysis_scope
), expected_scope AS (
  SELECT * FROM UNNEST([
    STRUCT('overall' AS scope,1 AS row_count),
    STRUCT('frequency',3),
    STRUCT('recency',3),
    STRUCT('joint',9)
  ])
)
SELECT 'MISSING_OR_BAD_FROZEN_SEGMENT' AS test_failure, e.analysis_key AS detail
FROM expected AS e
LEFT JOIN rpt AS r USING(analysis_key)
WHERE r.analysis_key IS NULL
  OR r.analysis_scope != e.scope
  OR r.clients != e.clients
  OR r.control_n != e.n0 OR r.control_positive != e.y0
  OR r.treatment_n != e.n1 OR r.treatment_positive != e.y1
  OR r.control_negative != e.n0 - e.y0
  OR r.treatment_negative != e.n1 - e.y1
  OR r.support_status != 'PASS_SUPPORT'
  OR r.history_end_date != DATE '2019-03-18'
  OR (
       e.std_rd_pp IS NOT NULL
       AND (
          r.pooled_std_rd_pp IS NULL
          OR ABS(r.pooled_std_rd_pp - e.std_rd_pp) > 0.0002
       )
     )
UNION ALL
SELECT 'UNEXPECTED_SEGMENT_KEY',r.analysis_key
FROM rpt AS r
LEFT JOIN expected AS e USING(analysis_key)
WHERE e.analysis_key IS NULL
UNION ALL
SELECT 'BAD_SCOPE_PARITY',e.scope
FROM expected_scope AS e
LEFT JOIN scope_totals AS s ON e.scope=s.analysis_scope
CROSS JOIN source AS b
WHERE s.analysis_scope IS NULL
  OR s.scope_rows!=e.row_count
  OR s.clients!=b.n OR s.n0!=b.n0 OR s.n1!=b.n1
  OR s.y0!=b.y0 OR s.y1!=b.y1
  OR b.n!=200039 OR b.unique_clients!=200039
  OR b.n0!=100058 OR b.n1!=99981
  OR b.y0!=60363 OR b.y1!=63639
UNION ALL
SELECT 'BAD_DERIVED_METRIC_OR_INFERENCE_SCOPE',r.analysis_key
FROM rpt AS r
WHERE r.clients != r.control_n + r.treatment_n
  OR r.control_n != r.control_positive + r.control_negative
  OR r.treatment_n != r.treatment_positive + r.treatment_negative
  OR r.control_response_pct IS NULL
  OR r.treatment_response_pct IS NULL
  OR r.observed_rd_pp IS NULL OR r.observed_rr IS NULL
  OR ABS(r.control_response_pct
       -100*SAFE_DIVIDE(r.control_positive,r.control_n)) > 1e-8
  OR ABS(r.treatment_response_pct
       -100*SAFE_DIVIDE(r.treatment_positive,r.treatment_n)) > 1e-8
  OR ABS(r.observed_rd_pp
       -(r.treatment_response_pct-r.control_response_pct)) > 1e-8
  OR ABS(r.observed_rr-SAFE_DIVIDE(
       SAFE_DIVIDE(r.treatment_positive,r.treatment_n),
       SAFE_DIVIDE(r.control_positive,r.control_n))) > 1e-8
  OR (
    r.analysis_scope='joint' AND (
      r.rd_ci95_lower_pp IS NOT NULL
      OR r.rd_ci95_upper_pp IS NOT NULL
      OR r.rr_ci95_lower IS NOT NULL OR r.rr_ci95_upper IS NOT NULL
      OR r.pooled_std_rd_pp IS NOT NULL OR r.pooled_std_rr IS NOT NULL
      OR r.pooled_std_control_response_pct IS NOT NULL
      OR r.pooled_std_treatment_response_pct IS NOT NULL
      OR r.std_minus_raw_rd_pp IS NOT NULL
      OR r.ci_method IS NOT NULL
      OR r.inference_scope!='POST_HOC_DESCRIPTIVE_ONLY'
    )
  )
  OR (
    r.analysis_scope!='joint' AND (
      r.rd_ci95_lower_pp IS NULL OR r.rd_ci95_upper_pp IS NULL
      OR r.rr_ci95_lower IS NULL OR r.rr_ci95_upper IS NULL
      OR r.pooled_std_rd_pp IS NULL OR r.pooled_std_rr IS NULL
      OR r.pooled_std_control_response_pct IS NULL
      OR r.pooled_std_treatment_response_pct IS NULL
      OR r.std_minus_raw_rd_pp IS NULL
      OR r.ci_method!='WALD_RD_AND_LOG_KATZ_RR_UNADJUSTED_95'
      OR r.inference_scope!='MARGINAL_DESCRIPTIVE_WITH_UNADJUSTED_CI'
      OR ABS(
        r.pooled_std_rd_pp
        -(r.pooled_std_treatment_response_pct-r.pooled_std_control_response_pct)
      )>1e-8
      OR ABS(
        r.std_minus_raw_rd_pp-(r.pooled_std_rd_pp-r.observed_rd_pp)
      )>1e-8
      OR r.rd_ci95_lower_pp>r.observed_rd_pp
      OR r.rd_ci95_upper_pp<r.observed_rd_pp
    )
  )
UNION ALL
SELECT 'BAD_TOTAL_NUMBER_OF_REPORTING_ROWS',CAST(COUNT(*) AS STRING)
FROM rpt
HAVING COUNT(*)!=16
