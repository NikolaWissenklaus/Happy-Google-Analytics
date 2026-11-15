// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_audiences.js
//
// Audiences are generated from here (definitions/40_marts/audiences/audiences.js).
// "condition" is SQL over aud_user_features columns. Keep them simple, marketing will
// read this file to understand who is inside each list (and they will, believe me).
//
//   consent       ads -> only users with ads_storage granted go to activation tables
//   destinations  where activation is allowed to send it
//   kind          features (default) | price_drop (special logic, joins item price changes)
//   holdout_pct   optional, % of the audience never sent when cfg_lifts.holdout is on (default there)

module.exports = {
  audiences: [
    {
      name: "cart_abandoners_7d",
      description: "Added to cart in the last 7 days and did not buy after that",
      condition: "has_open_cart AND last_add_to_cart_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)",
      consent: "ads",
      destinations: ["google_ads", "meta", "crm"]
    },
    {
      name: "checkout_abandoners_high_value",
      description: "Started checkout in the last 3 days with cart above R$ 300 and did not buy",
      condition: "has_open_checkout AND last_begin_checkout_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY) AND open_checkout_value >= 300",
      consent: "ads",
      destinations: ["google_ads", "meta", "crm"]
    },
    {
      name: "browse_abandoners_14d",
      description: "Viewed products in the last 14 days, never added to cart in that period, not a recent buyer",
      condition: "view_item_14d > 0 AND add_to_cart_14d = 0 AND purchases_30d = 0",
      consent: "ads",
      destinations: ["google_ads", "meta"]
    },
    {
      name: "engaged_non_buyers_30d",
      description: "3+ engaged sessions in 30 days and never bought anything",
      condition: "engaged_sessions_30d >= 3 AND purchases_total = 0",
      consent: "ads",
      destinations: ["google_ads", "meta"]
    },
    {
      name: "one_time_buyers_30_90d",
      description: "Bought exactly once, between 30 and 90 days ago. Second purchase is the hardest one",
      condition: "purchases_total = 1 AND days_since_last_purchase BETWEEN 30 AND 90",
      consent: "ads",
      destinations: ["google_ads", "meta", "crm"]
    },
    {
      name: "lapsed_customers_90_180d",
      description: "Customers whose last purchase was 90 to 180 days ago",
      condition: "purchases_total >= 1 AND days_since_last_purchase BETWEEN 90 AND 180",
      consent: "ads",
      destinations: ["google_ads", "meta", "crm"]
    },
    {
      name: "vip_customers",
      description: "RFM Champions or top 5% lifetime revenue",
      condition: "rfm_segment = 'Champions' OR value_tier = 'top_5_pct'",
      consent: "ads",
      destinations: ["google_ads", "meta", "crm"]
    },
    {
      name: "loyal_at_risk",
      description: "Used to buy a lot, disappeared. Call them before the competitor does",
      condition: "rfm_segment IN ('At Risk', 'Cannot Lose Them')",
      consent: "ads",
      destinations: ["google_ads", "meta", "crm"]
    },
    {
      name: "high_propensity_non_buyers",
      description: "Purchase propensity score >= 0.6 and no purchase in the last 30 days",
      condition: "purchase_propensity >= 0.6 AND purchases_30d = 0",
      consent: "ads",
      destinations: ["google_ads", "meta"]
    },
    {
      name: "coupon_lovers",
      description: "Half or more of the orders used a coupon (2+ orders). Dont send full price campaigns to them",
      condition: "purchases_total >= 2 AND coupon_order_share >= 0.5",
      consent: "ads",
      destinations: ["meta", "crm"]
    },
    {
      name: "replenishment_due",
      description: "Repeat buyers whose expected next purchase date is within +-7 days",
      condition: "predicted_next_purchase_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY)",
      consent: "ads",
      destinations: ["crm", "meta"]
    },
    {
      name: "new_engaged_no_signup",
      description: "First seen in the last 7 days, 2+ engaged sessions, did not create an account",
      condition: "days_since_first_seen <= 7 AND engaged_sessions_30d >= 2 AND NOT has_signed_up",
      consent: "ads",
      destinations: ["google_ads", "meta"]
    },
    {
      name: "leads_not_converted_30d",
      description: "Generated a lead in the last 30 days and did not buy",
      condition: "leads_total > 0 AND last_lead_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) AND purchases_total = 0",
      consent: "ads",
      destinations: ["crm", "google_ads"]
    },
    {
      name: "churn_risk_high",
      description: "Customers with churn risk >= 0.7",
      condition: "purchases_total >= 1 AND churn_risk >= 0.7",
      consent: "ads",
      destinations: ["crm", "meta"]
    },
    {
      name: "lookalike_seed_top_ltv",
      description: "Top 10% customers by lifetime revenue, seed for lookalike / similar audiences",
      condition: "value_tier IN ('top_5_pct', 'top_10_pct')",
      consent: "ads",
      destinations: ["google_ads", "meta"]
    },
    {
      name: "price_drop_watchers",
      description: "Viewed an item in the last 30 days whose price dropped 5%+ since the view. Perfect for 'baixou o preco' messages",
      kind: "price_drop",
      min_drop_pct: 0.05,
      consent: "ads",
      destinations: ["crm", "meta"]
    }
  ]
};
