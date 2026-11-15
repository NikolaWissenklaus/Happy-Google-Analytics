// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_anomaly.js
//
// Anomaly detection settings. Several methods run side by side and anom_ensemble only
// raises an alert when enough of them agree, otherwise we would get an alert every
// monday morning just because monday is monday.

module.exports = {
  history_days: 180,
  min_history_points: 21,

  zscore: { window_days: 28, threshold: 3.0 },
  same_weekday: { weeks: 8, threshold: 3.0 },
  mad: { window_days: 56, threshold: 3.5 },
  iqr: { window_days: 56, k: 1.5 },
  ewma: { lambda: 0.3, sigma_limit: 3.0, baseline_days: 56 },
  cusum: { k: 0.5, h: 5.0, baseline_days: 56 },
  change_point: { window_days: 14, t_threshold: 4.0 },

  // votes needed to raise an alert in the ensemble (max = number of methods = 8)
  ensemble_min_votes: 3,
  // holidays and big retail dates (black friday...) need more votes, they are "expected" weird days
  ensemble_min_votes_on_special_days: 5,

  // metric series monitored (see anom_metric_series_daily)
  metrics: [
    "sessions", "users", "new_users", "engaged_sessions", "engagement_rate", "page_views",
    "events", "key_events", "transactions", "revenue", "conversion_rate", "average_order_value",
    "add_to_cart_rate", "checkout_rate", "consent_denied_rate", "unassigned_share", "bot_share"
  ],
  // breakdowns. "all" is the total of the property
  breakdowns: ["all", "device_category", "session_default_channel_group", "platform"],

  // dimensions scanned by the automatic root cause (anom_root_cause)
  root_cause_dimensions: [
    "session_default_channel_group", "session_source_medium", "device_category", "device_browser",
    "device_os", "geo_country", "geo_region", "landing_page_type", "platform", "hostname"
  ]
};
