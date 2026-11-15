// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Assertions of the marts: math that must hold no matter the data.

function check(name, description, query, extraTags = []) {
  assert(name, {
    description,
    tags: ["assertions", "daily"].concat(extraTags)
  }).query(query);
}

check("assert_attribution_credits_sum_to_one",
  "Every rule based model must split 100% of each conversion between its touchpoints (tolerance 0.001)",
  ctx => `
WITH per_conversion AS (
  SELECT
    conversion_id,
    SUM(credit_first_click) AS first_click,
    SUM(credit_last_click) AS last_click,
    SUM(credit_last_non_direct) AS last_non_direct,
    SUM(credit_linear) AS linear,
    SUM(credit_time_decay) AS time_decay,
    SUM(credit_position_based) AS position_based,
    SUM(credit_w_shaped) AS w_shaped
  FROM ${ctx.ref("attr_credits_rule_based")}
  WHERE conversion_date >= DATE_SUB(CURRENT_DATE('${constants.TIMEZONE}'), INTERVAL 30 DAY)
  GROUP BY conversion_id
)
SELECT *
FROM per_conversion
WHERE ABS(first_click - 1) > 0.001
   OR ABS(last_click - 1) > 0.001
   OR ABS(last_non_direct - 1) > 0.001
   OR ABS(linear - 1) > 0.001
   OR ABS(time_decay - 1) > 0.001
   OR ABS(position_based - 1) > 0.001
   OR ABS(w_shaped - 1) > 0.001`, ["attribution"]);

check("assert_closed_funnels_never_grow",
  "In a closed funnel a step can never have more people than the step before it",
  ctx => `
SELECT funnel_name, step_number, closed_count, previous_closed_count
FROM (
  SELECT
    funnel_name,
    step_number,
    closed_count,
    LAG(closed_count) OVER (PARTITION BY funnel_name ORDER BY step_number) AS previous_closed_count
  FROM ${ctx.ref("fnl_overview")}
)
WHERE closed_count > previous_closed_count`, ["funnels"]);

check("assert_key_events_still_arriving",
  "A key event that used to arrive every day stopped (watch_event_registry status = gone). Usually a deploy removed the tag",
  ctx => `
SELECT event_name, last_seen_date, avg_week_before
FROM ${ctx.ref("watch_event_registry")}
WHERE is_key_event
  AND status = 'gone'`, ["ga4_watch"]);

check("assert_data_trust_index_not_critical",
  "Data Trust Index of the last day below 50: the numbers of today should not go to a board meeting",
  ctx => `
SELECT check_date, data_trust_index, failing_checks
FROM ${ctx.ref("dq_data_trust_index_daily")}
WHERE check_date = (SELECT MAX(check_date) FROM ${ctx.ref("dq_data_trust_index_daily")})
  AND data_trust_index < 50`, ["data_quality"]);

check("assert_incremental_models_not_stuck",
  "An incremental model has not loaded for more than 30 hours (the watermarks say so)",
  ctx => `
SELECT object_name, last_loaded_at, hours_since_load
FROM ${ctx.ref("ops_pipeline_freshness")}
WHERE object_kind = 'incremental'
  AND is_late`, ["ops"]);
