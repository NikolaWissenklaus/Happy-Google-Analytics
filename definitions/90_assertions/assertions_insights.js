// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Assertions of the insights models (tag: insights): math that must hold no matter the data.
// If one of these fails, the model has a bug, not the business.

function check(name, description, query, extraTags = []) {
  assert(name, {
    description,
    tags: ["assertions", "daily", "insights"].concat(extraTags)
  }).query(query);
}

check("assert_insights_kpi_tree_effects_add_up",
  "LMDI: the five effects of biz_kpi_tree_weekly must add up to the revenue change (no residual), tolerance 0.1%",
  ctx => `
SELECT week_start, segment, comparison, revenue_change,
  effect_users + effect_frequency + effect_conversion + effect_items_per_order + effect_price_per_item AS sum_of_effects
FROM ${ctx.ref("biz_kpi_tree_weekly")}
WHERE is_decomposable
  AND ABS(effect_users + effect_frequency + effect_conversion + effect_items_per_order + effect_price_per_item - revenue_change)
    > 0.001 * ABS(revenue_change) + 0.01`, ["business"]);

check("assert_insights_budget_reallocation_keeps_the_budget",
  "mkt_budget_reallocation moves money, it does not create it: the suggested total must stay within 2% of the current total",
  ctx => `
SELECT DISTINCT total_daily_budget, budget_gap
FROM ${ctx.ref("mkt_budget_reallocation")}
WHERE ABS(budget_gap) > 0.02 * total_daily_budget`, ["marketing"]);

check("assert_insights_weekday_indexes_average_one",
  "ds_kpi_decomposition: the 7 weekday indexes of a KPI are normalized, their average must be 1",
  ctx => `
SELECT kpi, AVG(weekday_index) AS average_index
FROM (
  SELECT DISTINCT kpi, iso_weekday, weekday_index
  FROM ${ctx.ref("ds_kpi_decomposition")}
  WHERE weekday_index IS NOT NULL
)
GROUP BY kpi
HAVING ABS(AVG(weekday_index) - 1) > 0.001`, ["data_science"]);

check("assert_insights_regimes_do_not_overlap",
  "ds_kpi_regimes: the regimes of a KPI are consecutive and never overlap",
  ctx => `
SELECT kpi, regime_number, start_date, end_date, previous_end
FROM (
  SELECT *, LAG(end_date) OVER (PARTITION BY kpi ORDER BY regime_number) AS previous_end
  FROM ${ctx.ref("ds_kpi_regimes")}
)
WHERE start_date > end_date
   OR start_date <= previous_end`, ["data_science"]);

check("assert_insights_funnel_rates_are_rates",
  "cro_funnel_weekly_step_changes: a closed funnel step can not have more sessions than the step before",
  ctx => `
SELECT week_start, segment_type, segment_value, step_name, entered, continued
FROM ${ctx.ref("cro_funnel_weekly_step_changes")}
WHERE continued > entered
   OR rate < 0
   OR rate > 1`, ["cro"]);

check("assert_insights_health_score_in_range",
  "seg_customer_health_score: the score and every component live between 0 and 100",
  ctx => `
SELECT user_key, health_score, recency_score, frequency_score, engagement_score, friction_score, discount_score
FROM ${ctx.ref("seg_customer_health_score")}
WHERE health_score NOT BETWEEN -0.001 AND 100.001
   OR recency_score NOT BETWEEN -0.001 AND 100.001
   OR frequency_score NOT BETWEEN -0.001 AND 100.001
   OR engagement_score NOT BETWEEN -0.001 AND 100.001
   OR friction_score NOT BETWEEN -0.001 AND 100.001
   OR discount_score NOT BETWEEN -0.001 AND 100.001`, ["segments"]);

check("assert_insights_bootstrap_intervals_are_ordered",
  "ds_bootstrap_channel_metrics: the lower end of an interval can not be above the upper end",
  ctx => `
SELECT channel, metric, ci_low, ci_high, diff_vs_site_ci_low, diff_vs_site_ci_high
FROM ${ctx.ref("ds_bootstrap_channel_metrics")}
WHERE ci_low > ci_high
   OR diff_vs_site_ci_low > diff_vs_site_ci_high`, ["data_science"]);
