SELECT
    treatment_flg,
    target,
    COUNT(*) AS customers

FROM x5_raw.uplift_train

GROUP BY
    treatment_flg,
    target

ORDER BY
    treatment_flg,
    target;
