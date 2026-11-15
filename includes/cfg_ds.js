// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_ds.js
//
// Data science settings. BQML models only run with enable_bqml = "true" (they cost money).
// BTYD (BG/NBD + Gamma-Gamma), statistics and the heuristic scores always run, they are
// plain SQL / JS UDFs and cheap.

module.exports = {
  features: {
    // columns of ds_feature_snapshots used by the BQML models
    model_columns: [
      "sessions_7d", "sessions_30d", "sessions_90d", "engaged_sessions_30d", "engagement_sec_30d", "views_30d",
      "product_views_30d", "cart_sessions_30d", "cart_sessions_7d", "checkout_sessions_30d", "search_sessions_30d",
      "active_days_30d", "distinct_channels_90d", "days_since_last_session", "main_channel", "main_device",
      "is_identified", "uses_app", "purchases_before", "revenue_before", "days_since_last_purchase",
      "coupon_share_before", "avg_order_value_before"
    ],
    // numeric columns for clustering (standardized by BQML)
    cluster_columns: [
      "sessions_90d", "engaged_sessions_30d", "engagement_sec_30d", "product_views_30d", "cart_sessions_30d",
      "search_sessions_30d", "active_days_30d", "days_since_last_session", "purchases_before", "revenue_before"
    ],
    lookback_days: 90,
    // weekly snapshots used for training. more snapshots = more rows = better model, more $$
    // (LTV labels need 90 days of future, so only the snapshots older than that get them)
    training_snapshots: 20,
    snapshot_every_days: 7
  },

  propensity: {
    horizon_days: 7,
    // LOGISTIC_REG is cheap and explainable. BOOSTED_TREE_CLASSIFIER is usually better
    model_type: "LOGISTIC_REG"
  },

  churn: {
    // customer is "churned" if no session in the next N days
    horizon_days: 30,
    model_type: "LOGISTIC_REG"
  },

  ltv: {
    horizon_days: 90,
    model_type: "BOOSTED_TREE_REGRESSOR"
  },

  clustering: {
    num_clusters: 6
  },

  forecast: {
    horizon_days: 90,
    confidence_level: 0.9,
    metrics: ["sessions", "transactions", "revenue"],
    holiday_region: "BR"
  },

  btyd: {
    // time unit for BG/NBD. weeks is the classic choice
    time_unit_days: 7,
    calibration_days: 365,
    prediction_horizon_units: 13,
    max_frequency: 50,
    penalizer: 0.001
  },

  mmm: {
    adstock_decay: 0.5,
    saturation_half_point_share: 0.5
  }
};
