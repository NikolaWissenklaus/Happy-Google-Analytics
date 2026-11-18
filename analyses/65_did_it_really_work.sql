-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- "the users of the wishlist buy 3x more" and "the TV in the south worked": causal inference without a vendor

-- 1) every feature: the naive difference against the matched effect (coarsened exact matching)
SELECT feature, treated_users, naive_diff_purchase_rate, att_purchase_rate, att_purchase_rate_low, att_purchase_rate_high,
       att_relative, selection_bias_removed, matched_treated_share, verdict
FROM `your-gcp-project.ga4_data_science.ds_feature_impact_cem`
ORDER BY ABS(att_purchase_rate) DESC;

-- 2) the geo test with a synthetic control: real vs synthetic, day by day (line chart)
SELECT experiment_id, metric, metric_date, period, actual, synthetic, gap, cumulative_gap
FROM `your-gcp-project.ga4_data_science.ds_geo_synthetic_control`
ORDER BY experiment_id, metric, metric_date;

-- 3) the verdict of the geo test: fit before, effect after, placebo p value and the states that make the synthetic
SELECT DISTINCT experiment_id, experiment_name, metric, pre_rmspe, post_rmspe, rmspe_ratio, placebos, placebo_p_value, relative_effect_test_period,
       (SELECT STRING_AGG(CONCAT(w.uf, ' ', FORMAT('%.0f', 100 * w.weight), '%'), ', ') FROM UNNEST(donor_weights) AS w) AS synthetic_made_of
FROM `your-gcp-project.ga4_data_science.ds_geo_synthetic_control`;

-- 4) synthetic control next to the difference-in-differences of the same experiment: when both agree, believe it
SELECT s.experiment_id, s.metric, s.relative_effect_test_period AS synthetic_control_effect, d.relative_lift AS did_effect,
       d.groups_look_comparable, s.placebo_p_value
FROM (
  SELECT DISTINCT experiment_id, metric, relative_effect_test_period, placebo_p_value
  FROM `your-gcp-project.ga4_data_science.ds_geo_synthetic_control`
) AS s
LEFT JOIN `your-gcp-project.ga4_data_science.ds_geo_experiment_did` AS d USING (experiment_id)
WHERE s.metric = 'revenue';
