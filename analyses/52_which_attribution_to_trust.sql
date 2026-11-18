-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- "which attribution model is right?" none. The useful question is: where do the models AGREE
-- (safe to act) and where do they DISAGREE (test before moving money). This reads the extended
-- attribution (tag attribution_extended, docs/attribution_extended.md).

-- 1) one line per channel: consensus, spread, data driven vs GA4 default, verdict
SELECT
  channel,
  ANY_VALUE(consensus_share) AS consensus_share,
  ANY_VALUE(min_share) AS min_share,
  ANY_VALUE(max_share) AS max_share,
  ANY_VALUE(disagreement_cv) AS disagreement_cv,
  ANY_VALUE(last_non_direct_share) AS ga4_default_share,
  ANY_VALUE(data_driven_share) AS data_driven_share,
  ANY_VALUE(data_driven_vs_last_click) AS data_driven_vs_last_click,
  ANY_VALUE(verdict) AS verdict
FROM `your-gcp-project.ga4_attribution.attr_model_consensus`
GROUP BY channel
ORDER BY consensus_share DESC;

-- 2) the full matrix channel x model (paste in a sheet with a heatmap)
SELECT channel, model, model_family, ROUND(share, 4) AS share, rank_in_model
FROM `your-gcp-project.ga4_attribution.attr_model_consensus`
ORDER BY channel, model_family, model;

-- 3) how much of the conversions would happen WITHOUT any touch (baseline of the survival model)
-- and the marginal conversions of one more touch of each channel
SELECT channel, beta, conversions_per_1000_touches, share, share_without_baseline, half_life_days
FROM `your-gcp-project.ga4_attribution.attr_additive_hazard`
ORDER BY channel = '(baseline)' DESC, share DESC;

-- 4) marginal cost of a conversion per channel: cost / (touches x beta), last 90 days
-- (paid channels only; the platform -> channel mapping is yours, adjust the CASE)
WITH cost AS (
  SELECT
    CASE
      WHEN LOWER(platform) LIKE '%google%' THEN 'Paid Search'
      WHEN LOWER(platform) LIKE '%meta%' OR LOWER(platform) LIKE '%facebook%' THEN 'Paid Social'
      ELSE 'Paid Other'
    END AS channel,
    SUM(cost) AS cost
  FROM `your-gcp-project.ga4_core.fct_ad_costs_daily`
  WHERE cost_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  GROUP BY 1
)
SELECT h.channel, c.cost, h.touches, h.beta, h.touches * h.beta AS incremental_conversions,
       SAFE_DIVIDE(c.cost, h.touches * h.beta) AS cost_per_incremental_conversion
FROM `your-gcp-project.ga4_attribution.attr_additive_hazard` AS h
JOIN cost AS c USING (channel)
ORDER BY cost_per_incremental_conversion;

-- 5) channels that work better together (and the ones that fight for the same people)
SELECT channel_i, channel_j, journeys_both, p_i_alone, p_j_alone, p_both, synergy_index, relationship
FROM `your-gcp-project.ga4_attribution.attr_channel_synergy`
WHERE relationship != 'independent'
ORDER BY synergy_index DESC;

-- 6) does the ORDER of the channels matter? biggest credit moves from Markov order 1 to 2
SELECT channel, markov_order, share, share_change_vs_order_1, states, median_state_visits
FROM `your-gcp-project.ga4_attribution.attr_markov_higher_order`
WHERE markov_order > 1
ORDER BY ABS(share_change_vs_order_1) DESC;

-- 7) the learned half life vs the GA4 default of 7 days (if it is very different, time decay
-- with 7 days was giving the credit to the wrong touches)
SELECT ANY_VALUE(learned_half_life_days) AS learned_half_life_days
FROM `your-gcp-project.ga4_attribution.attr_credits_rule_based_extended`;

-- before moving budget on a channel with verdict 'models_disagree': run a holdout or a geo test
-- (ga4_lifts, ga4_data_science.ds_geo_experiment_did)
