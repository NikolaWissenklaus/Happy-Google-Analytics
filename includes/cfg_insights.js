// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_insights.js
//
// Knobs of the "insights" models (tag: insights). One more floor on top of labs, frontier and
// attribution_extended, organized by the level of who asks: from the question of the first week
// of a junior analyst ("is the average session lying to me?") to the models a specialist would
// build (Cox, synthetic control, Bass diffusion, Louvain communities, Poisson bootstrap).
// docs/insights.md has the question, the math and the level of each one. Everything here is a
// starting point for a mid size brazilian e-commerce: tune it with your own numbers.

module.exports = {
  // ------------------------------------------------------------------ sessions and flows

  // prod_session_distribution_daily: percentiles instead of averages
  session_distribution: {
    // sessions longer than this count as "long" (minutes of engagement)
    long_session_minutes: 10
  },

  // prod_session_intent_taxonomy: what the visit was FOR. Broder's taxonomy of web searches
  // (navigational / informational / transactional, 2002) applied to sessions, plus the intents
  // an e-commerce has and a search engine does not (cart building, post purchase service...)
  session_intent: {
    window_days: 60,
    // sessions that did not buy: did the same person buy in the next N days?
    later_purchase_days: 7,
    // first match wins. condition = SQL over the features of the session:
    //   has_purchase, has_begin_checkout, has_add_to_cart, is_engaged, views, distinct_products,
    //   category_views, search_views, content_views, account_views, service_views, home_views,
    //   cart_views, landing_page_type, is_new_user, engagement_time_sec
    intents: [
      { intent: "buy", family: "transactional", condition: "has_purchase" },
      { intent: "checkout_abandoned", family: "transactional", condition: "has_begin_checkout" },
      { intent: "cart_building", family: "transactional", condition: "has_add_to_cart OR cart_views > 0" },
      { intent: "post_purchase_service", family: "service", condition: "service_views > 0" },
      { intent: "account_navigation", family: "navigational", condition: "account_views > 0 AND distinct_products = 0" },
      { intent: "bounce", family: "unknown", condition: "views <= 1 AND NOT is_engaged" },
      { intent: "comparison_research", family: "commercial", condition: "distinct_products >= 3" },
      { intent: "product_focused", family: "commercial", condition: "distinct_products >= 1" },
      { intent: "exploratory_browse", family: "commercial", condition: "category_views + search_views > 0" },
      { intent: "informational_content", family: "informational", condition: "content_views > 0" },
      { intent: "home_and_navigation", family: "navigational", condition: "TRUE" }
    ],
    // page types (cfg_project.page_types) that count as content
    content_page_types: ["blog", "institutional", "landing_page"]
  },

  // prod_dwell_time_mixture: every page has two populations, the ones that skim and the ones that read
  dwell_mixture: {
    window_days: 30,
    max_pages: 300,
    min_views: 200,
    // values sent to the JS UDF per page (deterministic sample)
    sample_per_page: 4000,
    // time on page above this is a forgotten tab, not reading
    max_seconds: 1800,
    em_iterations: 300,
    // Ashman's D above this = the two groups are really separated
    min_separation: 2
  },

  // prod_flow_divergence_buyers: where the navigation of buyers diverges from the others
  flow_divergence: {
    window_days: 30,
    // only the "discovery" part of the session: everything before the first page of these types
    decision_page_types: ["cart", "checkout", "thank_you"],
    min_transition_sessions: 100,
    over_represented_lift: 1.5
  },

  // prod_flow_sankey: edges ready for a Sankey chart (Looker Studio, Power BI, Flourish...)
  sankey: {
    window_days: 30,
    max_steps: 6,
    // channels outside the top N become 'Other' in the channel segment
    top_channels: 8,
    // TRUE = product > product > product becomes one 'product' step (GA4 path exploration style)
    collapse_repeats: false,
    // edges with fewer sessions are left out (a Sankey with 2000 thin lines says nothing)
    min_edge_sessions: 10
  },

  // ------------------------------------------------------------------ funnels and experiments

  // cro_funnel_weekly_step_changes: which step of the funnel broke (or improved) this week
  funnel_weekly: {
    weeks: 12,
    // the baseline of a week is the average of the N weeks before the previous one
    baseline_weeks: 4,
    // false discovery rate (Benjamini-Hochberg) of the tests of each week
    fdr: 0.1,
    min_entered: 200,
    top_channels: 6,
    // closed funnel over the fct_sessions flags, in this order
    steps: [
      { step: "view_item", flag: "has_view_item" },
      { step: "add_to_cart", flag: "has_add_to_cart" },
      { step: "begin_checkout", flag: "has_begin_checkout" },
      { step: "add_shipping_info", flag: "has_add_shipping_info" },
      { step: "add_payment_info", flag: "has_add_payment_info" },
      { step: "purchase", flag: "has_purchase" }
    ]
  },

  // coh_user_funnel_by_cohort: the funnel of PEOPLE across sessions, per acquisition week
  user_funnel: {
    cohort_weeks: 26,
    horizons_days: [0, 1, 7, 14, 30],
    steps: [
      { step: "view_item", flag: "has_view_item" },
      { step: "add_to_cart", flag: "has_add_to_cart" },
      { step: "begin_checkout", flag: "has_begin_checkout" },
      { step: "purchase", flag: "has_purchase" }
    ]
  },

  // cro_test_capacity_planner: can this page be A/B tested with the traffic it has?
  test_capacity: {
    window_days: 28,
    alpha: 0.05,
    power: 0.8,
    relative_lifts: [0.05, 0.1, 0.2],
    test_days: [14, 28, 56],
    top_landing_pages: 50,
    min_daily_sessions: 20
  },

  // cro_ab_test_segments: does the effect of the test change by segment (heterogeneity)?
  ab_segments: {
    min_users_per_cell: 200,
    fdr: 0.1
  },

  // ------------------------------------------------------------------ statistics and data science

  // ds_kpi_regimes: PELT change points on the deseasonalized daily KPIs
  regimes: {
    kpis: ["sessions", "conversion_rate", "average_order_value", "revenue", "engagement_rate", "add_to_cart_rate", "revenue_per_session"],
    // penalty = multiplier * 2 * ln(n). 1 = BIC. Higher = fewer and bigger regimes
    penalty_multiplier: 3,
    min_segment_days: 14,
    // regimes that differ less than this from the previous one are not "material"
    min_relative_change: 0.05,
    // interventions / promotions / special days this close to a change are listed as possible causes
    cause_window_days: 7,
    // a regime that started in the last N days is "new" (biz_insights_feed reads this)
    new_regime_days: 21
  },

  // ds_kpi_decomposition: trend x weekday x residual (classical multiplicative decomposition)
  decomposition: {
    kpis: ["sessions", "transactions", "revenue", "conversion_rate", "average_order_value", "engagement_rate"],
    unusual_residual_z: 3
  },

  // ds_kpi_forecast_holt_winters: forecast that works without BQML
  holt_winters: {
    kpis: ["sessions", "transactions", "revenue", "new_users"],
    history_days: 364,
    horizon_days: 28,
    // last N days are kept out of the fit to measure the error honestly (backtest)
    holdout_days: 28
  },

  // ds_bootstrap_channel_metrics: Poisson bootstrap by hash buckets (no normality assumption)
  bootstrap: {
    window_days: 28,
    buckets: 500,
    replicates: 200,
    min_sessions: 500
  },

  // ds_conversion_drivers_information: which dimension explains the purchase (mutual information)
  drivers: {
    window_days: 30,
    // values with fewer sessions are grouped in '(other)' before the math (cardinality bias)
    min_sessions_per_value: 200
  },

  // ds_second_purchase_cox: what in the FIRST order speeds up (or delays) the second one
  cox: {
    first_order_window_days: 540,
    max_followup_days: 365,
    // deterministic sample sent to the JS UDF
    max_subjects: 50000,
    l2: 0.01,
    iterations: 30,
    // covariates = SQL over the first order (fct_transactions columns + days_to_first_purchase of
    // dim_users). type bool becomes 0/1, number is used as it is
    covariates: [
      { name: "used_coupon", type: "bool", sql: "coupon IS NOT NULL" },
      { name: "deferred_payment", type: "bool", sql: "is_deferred_payment" },
      { name: "paid_media_first_order", type: "bool", sql: "REGEXP_CONTAINS(COALESCE(session_default_channel_group, ''), r'^(Paid|Display|Cross-network)')" },
      { name: "crm_channel_first_order", type: "bool", sql: "session_default_channel_group IN ('Email', 'SMS', 'Mobile Push Notifications')" },
      { name: "mobile", type: "bool", sql: "device_category = 'mobile'" },
      { name: "log_order_value", type: "number", sql: "LN(1 + GREATEST(COALESCE(revenue, 0), 0))" },
      { name: "multi_unit_order", type: "bool", sql: "COALESCE(item_quantity, 1) > 1" },
      { name: "logged_in_customer", type: "bool", sql: "STARTS_WITH(user_key, 'uid:')" },
      { name: "bought_on_first_day", type: "bool", sql: "days_to_first_purchase = 0" }
    ]
  },

  // ds_feature_impact_cem: did using the feature change the purchases? Coarsened exact matching
  cem: {
    // exposure window = the N days that end outcome_days ago; outcome = the outcome_days after it
    exposure_days: 30,
    outcome_days: 30,
    prior_days: 90,
    min_treated: 100,
    // null = cfg_project.features
    features: null
  },

  // ds_geo_synthetic_control: the geo test of cfg_experiments with a synthetic control state
  synthetic_control: {
    metrics: ["revenue", "sessions"],
    // all_other_ufs = every state outside the test is a donor | control_ufs = only the listed ones
    donor_pool: "all_other_ufs",
    min_pre_daily_sessions: 30,
    iterations: 5000
  },

  // ------------------------------------------------------------------ ecommerce

  // ecom_launch_bass_diffusion: how a new product spreads (innovation p x imitation q)
  bass: {
    launch_window_days: 180,
    min_weeks: 6,
    min_adopters: 50,
    horizon_weeks: 8,
    // q / p above this = spread by word of mouth, below 1 = pushed by media
    word_of_mouth_q_over_p: 10
  },

  // ecom_product_communities: the departments the customers draw with their navigation (Louvain)
  communities: {
    window_days: 90,
    max_items: 2000,
    max_items_per_session: 20,
    min_co_sessions: 5,
    min_lift: 1.5,
    // an item is "misplaced" when its category is not the one that dominates its community
    // and the community is at least this pure
    misplaced_purity: 0.6
  },

  // ecom_abc_xyz_classification: value (ABC) x predictability (XYZ) + Syntetos-Boylan demand type
  abc_xyz: {
    weeks: 26,
    abc_cut: [0.8, 0.95],
    xyz_cut: [0.5, 1.0],
    // Syntetos & Boylan (2005): average demand interval and squared CV of the non zero demand
    adi_cut: 1.32,
    cv2_cut: 0.49,
    policies: {
      AX: "auto replenishment, never let it break",
      AY: "replenish weekly, safety stock on the peaks",
      AZ: "high value and erratic: watch demand signals (views, carts) and keep safety stock",
      BX: "auto replenishment with lower service level",
      BY: "periodic review",
      BZ: "order on demand signals, small safety stock",
      CX: "lean stock, consider bundles",
      CY: "lean stock, review the assortment",
      CZ: "candidate to delist or to sell on demand / dropshipping"
    }
  },

  // ------------------------------------------------------------------ marketing

  // mkt_spend_response_curves: revenue = a + b ln(1 + spend), per campaign
  response_curves: {
    window_days: 180,
    min_days: 30,
    // without variation of the spend there is no curve to learn
    min_spend_cv: 0.15,
    // marginal ROAS to aim for. null = 1 / cfg_project.assumed_gross_margin (break even on margin)
    target_marginal_roas: null,
    test_increment_per_day: 1000
  },

  // mkt_budget_reallocation: same total budget, split to equalize the marginal ROAS
  budget_reallocation: {
    max_cut: 0.5,
    max_increase: 0.5,
    grid_points: 2000
  },

  // mkt_campaign_taxonomy: the naming convention of the campaigns, parsed and audited
  campaign_taxonomy: {
    window_days: 90,
    delimiter: "_",
    min_sessions: 30,
    // position = order in the name. ex: conversion_remarketing_cart-abandoners_frete-gratis_br_202611
    fields: [
      { name: "objective", required: true, allowed: "^(awareness|consideration|conversion|retention|aw|co|cv|rt)$" },
      { name: "funnel_stage", required: true, allowed: "^(tofu|mofu|bofu|prospecting|remarketing|retargeting|crm)$" },
      { name: "audience", required: true, allowed: "^[a-z0-9-]+$" },
      { name: "offer", required: false, allowed: "^[a-z0-9-]+$" },
      { name: "geo", required: false, allowed: "^[a-z]{2,3}$" },
      { name: "launch", required: false, allowed: "^20[0-9]{2}(0[1-9]|1[0-2])?$" }
    ]
  },

  // mkt_message_match: does the landing page talk about what the person searched?
  message_match: {
    window_days: 30,
    min_sessions: 30
  },

  // mkt_cohort_roas_by_campaign: ROAS D0 / D7 / D30 / D90 / D180 of the people each campaign brought
  cohort_roas: {
    months: 13,
    horizons_days: [0, 7, 30, 60, 90, 180],
    min_users: 50
  },

  // ------------------------------------------------------------------ business and customers

  // biz_kpi_tree_weekly: revenue = users x sessions per user x conversion x items per order x price per item
  kpi_tree: {
    weeks: 12
  },

  // biz_target_hit_probability
  target_probability: {
    history_weeks: 8,
    // daily values are not independent (good weeks come together): inflate the variance
    variance_inflation: 1.5
  },

  // seg_customer_health_score: 0-100 per customer, like customer success does in SaaS
  health: {
    weights: { recency: 0.4, frequency: 0.2, engagement: 0.2, friction: 0.15, discount: 0.05 },
    bands: { healthy: 70, watch: 50, at_risk: 30 },
    friction_window_days: 365
  },

  // biz_insights_feed: thresholds to turn the tables above into sentences
  insights_feed: {
    min_revenue_impact: 1000,
    target_probability_low: 0.3,
    target_probability_high: 0.9,
    export_limit_warn_days: 60,
    max_rows: 50
  },

  // ------------------------------------------------------------------ data engineering

  // dq_export_limit_headroom: GA4 standard properties export at most 1 million events per day to
  // BigQuery (daily export). Above it Google pauses the export. 360 properties have a much bigger limit
  export_limit: {
    daily_event_limit: 1000000,
    window_days: 56,
    trend_days: 28
  },

  // ops_event_storage_footprint: who eats the bytes of the export
  storage: {
    window_days: 7,
    // fixed columns of a row (device, geo, traffic_source...), an estimate in bytes
    other_columns_bytes: 1200,
    // one element of the items array (ids, names, categories, price...), an estimate in bytes
    item_row_bytes: 250,
    // active logical storage, USD per GiB per month (check the price of your region)
    usd_per_gib_month: 0.02
  },

  // ------------------------------------------------------------------ seo (need enable_search_console)

  // seo_ctr_collapse: same position, same impressions, much fewer clicks = the SERP ate the click
  ctr_collapse: {
    window_days: 28,
    min_impressions: 200,
    max_position_change: 1.0,
    min_relative_ctr_drop: 0.3
  },

  // seo_query_intent: the intent of every query (accents removed before matching). first match wins
  query_intent: {
    window_days: 90,
    intents: [
      { intent: "navigational", pattern: "(login|entrar|minha conta|rastre|pedido|\\bsac\\b|telefone|whatsapp|contato|endereco|loja fisica|horario)" },
      { intent: "transactional", pattern: "(comprar|compra|preco|valor|quanto custa|barato|promoc|oferta|desconto|cupom|frete|entrega|parcel|\\bpix\\b|boleto|black friday|outlet)" },
      { intent: "commercial", pattern: "(melhor|melhores|\\btop\\b|review|avaliac|resenha|vale a pena|comparativ|\\bvs\\b|\\bx\\b|qual escolher|reclame aqui|confiavel|e bom)" },
      { intent: "informational", pattern: "(^como |\\bcomo\\b|o que|oque|por que|porque|quando|\\bqual\\b|\\bquais\\b|\\bonde\\b|dicas|tutorial|significado|serve para|beneficios|diferenca|tipos de|guia)" },
      { intent: "local", pattern: "(perto de mim|proximo|\\bem sp\\b|bairro)" }
    ]
  }
};
