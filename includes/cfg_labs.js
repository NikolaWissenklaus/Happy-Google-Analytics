// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_labs.js
//
// Knobs of the "labs" models (tag: labs): the analyses that go beyond what a GA4 report would
// ever show (docs/labs.md has the idea and the math of each one). Everything here is a
// starting point for a mid size brazilian e-commerce, tune it with your own numbers.

module.exports = {
  // ds_shopping_missions: sessions of the same person are glued in one "mission" while the
  // pause between them is shorter than this. A purchase always closes the mission
  missions: {
    window_days: 180,
    max_gap_days: 3
  },

  // seg_visit_rhythm: habit of each user (burstiness, streaks, trend)
  rhythm: {
    window_days: 180,
    // with less active days than this there is no rhythm to measure
    min_active_days: 4,
    // days late = this many times the usual gap of the user -> "broke the habit"
    overdue_gap_multiplier: 2
  },

  // mkt_traffic_bursts: minutes where a channel receives way more session starts than the hour before
  bursts: {
    window_days: 30,
    min_sessions_per_minute: 8,
    // (sessions - baseline) / sqrt(baseline), a poisson z score
    min_z: 5,
    // flagged minutes closer than this are the same burst
    merge_gap_minutes: 3
  },

  // dq_tracking_blackouts: minutes without ANY event when the hour of the week usually has traffic
  blackouts: {
    window_days: 14,
    baseline_days: 42,
    min_expected_events_per_minute: 3,
    min_gap_minutes: 5
  },

  // prod_session_timeout_splits: a session that starts up to this many minutes after the
  // previous one of the same device ended is the same visit cut by the 30 min timeout
  timeout_splits: {
    max_gap_minutes: 120
  },

  // prod_internal_pagerank
  pagerank: {
    window_days: 30,
    max_pages: 1500,
    damping: 0.85,
    iterations: 40
  },

  // prod_post_purchase_behavior: what the customer does in the days after the order.
  // regex on page_path (lower case, no query string)
  post_purchase: {
    window_days: 30,
    order_tracking_pattern: "(rastre|tracking|meus-pedidos|my-orders|pedido|order-status|acompanh)",
    support_pattern: "(contato|contact|fale-conosco|ajuda|help|faq|atendimento|sac|chat|reclam)",
    returns_pattern: "(troca|devolu|return|exchange|cancel|reembolso|refund|arrependimento)"
  },

  // ecom_replenishment_cycles
  replenishment: {
    min_repeat_buyers: 10,
    // "due" window around the median cycle: from 0.8x to 1.5x. after that the customer is overdue
    due_from: 0.8,
    due_to: 1.5
  },

  // ecom_item_momentum
  momentum: {
    min_views_for_trend: 50,
    launch_days: 21
  },

  // ecom_list_position_bias
  position_bias: {
    window_days: 90,
    min_impressions: 200,
    max_position: 60
  },

  // ds_order_risk_signals: points of each signal (the score is the sum, capped at 100).
  // it is a queue for manual review, NOT an anti fraud system
  order_risk: {
    window_days: 90,
    weights: {
      order_velocity: 30,
      payment_retries: 15,
      new_device_high_value_fast: 25,
      unusual_location: 15,
      night_owl_high_value: 10,
      bot_like_device: 25,
      shared_device: 10,
      value_outlier: 15
    },
    orders_in_24h: 3,
    fast_checkout_seconds: 180,
    review_from_score: 50
  },

  // mkt_in_app_browser_gap: GA4 browser names that mean "webview inside another app"
  in_app_browser_pattern: "(webview|in-app|instagram|facebook|fban|fbav|tiktok|musical_ly|line/|snapchat|pinterest|linkedin|twitter)",

  // gov_url_parameter_inventory
  url_params: {
    window_days: 30,
    click_ids: ["gclid", "gbraid", "wbraid", "dclid", "fbclid", "msclkid", "ttclid", "twclid", "li_fat_id", "srsltid", "gad_source", "gad_campaignid", "gclsrc", "_gl", "_ga", "mc_cid", "mc_eid", "igshid", "epik", "yclid", "sccid"],
    // above this share of distinct values per hit the param is unique per hit (session id,
    // timestamp, token): it explodes the page reports of GA4 into "(other)"
    cardinality_bomb_ratio: 0.5
  },

  // cro_empirical_bayes_rates
  empirical_bayes: {
    window_days: 90,
    min_sessions_for_prior: 30
  },

  // cro_ab_test_sequential: variance of the prior of the effect in the mixture SPRT.
  // 0.0001 = "true differences of around 1 percentage point" (sqrt(0.0001) = 0.01)
  sequential_tau_squared: 0.0001,

  // cro_ab_test_cuped: days before the exposure used as the covariate
  cuped_pre_period_days: 28
};
