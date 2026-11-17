-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- before believing (or presenting) a number. Four checks that take one minute.

-- 1) did conversion really change, or was it the mix of traffic?
SELECT DISTINCT dimension, ROUND(total_change, 5) AS total_conversion_change, ROUND(dimension_mix_effect, 5) AS mix_effect,
  ROUND(dimension_rate_effect, 5) AS rate_effect, is_simpson_paradox, reading
FROM `your-gcp-project.ga4_business.biz_simpson_paradox_watch`
ORDER BY is_simpson_paradox DESC, dimension;

-- 2) is this the best campaign / landing page, or just a lucky one with 9 sessions?
SELECT entity_type, entity, sessions, purchases, ROUND(raw_rate, 4) AS raw_rate, raw_rank,
  ROUND(shrunk_rate, 4) AS shrunk_rate, shrunk_rank, verdict
FROM `your-gcp-project.ga4_cro.cro_empirical_bayes_rates`
WHERE entity_type = 'campaign'
ORDER BY shrunk_rank
LIMIT 30;

-- 3) can I stop the A/B test today? (yes only if can_stop, whatever the classic p value says)
SELECT experiment_name, variant_id, day, users, ROUND(cumulative_uplift, 3) AS uplift, ROUND(naive_p_value, 4) AS naive_p_value,
  ROUND(always_valid_p_value, 4) AS always_valid_p_value, can_stop, peeking_trap, days_in_peeking_trap, decision
FROM `your-gcp-project.ga4_cro.cro_ab_test_sequential`
WHERE is_latest_day;

-- 4) why does this day not match the GA4 screen?
SELECT event_date, biggest_expected_cause, ROUND(cookieless_event_share, 3) AS cookieless_event_share,
  ROUND(midnight_session_share, 3) AS midnight_session_share, ROUND(user_id_dedup_share, 3) AS user_id_dedup_share,
  repeated_purchase_events, hll_users_margin, expected_direction
FROM `your-gcp-project.ga4_data_quality.dq_ui_vs_bigquery_explainer`
ORDER BY event_date DESC
LIMIT 14;

-- bonus: how many of the "users" are the same person with a new cookie
SELECT device_category, device_browser, known_people, ROUND(cookies_per_person, 2) AS cookies_per_person,
  median_cookie_lifespan_days, ROUND(share_dead_within_7_days, 2) AS share_dead_within_7_days,
  reported_users_90d, ROUND(estimated_real_users_90d) AS estimated_real_users_90d
FROM `your-gcp-project.ga4_marketing.mkt_cookie_churn_inflation`
ORDER BY reported_users_90d DESC;
