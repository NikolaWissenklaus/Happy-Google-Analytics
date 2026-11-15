// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_lifts.js
//
// Lift = how much something really changed the result. Three ways here, from the most
// trustworthy to the least:
//   1) holdout: a random part of the people is NOT impacted (audience not sent, CRM e-mail not
//      sent) and we compare. Real incrementality, the only one that is causal by design.
//   2) interventions: a dated change (new checkout, redesign, price change, national TV) measured
//      against the counterfactual of the pre period (interrupted time series), with a control
//      series when there is one.
//   3) behaviours: sessions that did X convert N times more, adjusted by device, new / returning,
//      channel and landing page type (Mantel-Haenszel). Association, not causation, but way less
//      naive than the raw comparison.
// A/B tests, promotions and geo experiments already have their own tables, lift_registry puts
// everything in one place.

module.exports = {
  holdout: {
    // OFF until marketing agrees: with it on, X% of each audience / CRM trigger is never sent
    enabled: false,
    audiences_pct: 10,
    crm_triggers_pct: 10,
    // the day the holdout was turned on. cohorts before it were sent to everybody, they do not count
    start_date: "2026-12-01",
    // purchases counted this many days after entering the audience / receiving the trigger
    outcome_window_days: 14,
    min_users_per_group: 100
  },

  // dated changes to measure. metrics: sessions, engaged_sessions, transactions, revenue,
  // conversion_rate, engagement_rate, average_order_value, add_to_cart_rate, checkout_rate.
  // segment / control dimensions: device_category, channel, uf, platform
  interventions: [
    // {
    //   name: "one_page_checkout_mobile",
    //   description: "New one page checkout, mobile only",
    //   start_date: "2026-03-10",
    //   end_date: null,
    //   pre_days: 56,
    //   post_days: 28,
    //   metrics: ["conversion_rate", "revenue", "checkout_rate"],
    //   segment: { dimension: "device_category", value: "mobile" },
    //   control: { dimension: "device_category", value: "desktop" }
    // }
  ],

  behaviors: {
    window_days: 30,
    min_sessions_with_behavior: 300,
    max_behaviors: 60,
    // these say nothing about intent (or are the outcome itself)
    ignore_events: [
      "session_start", "first_visit", "first_open", "user_engagement", "page_view", "screen_view",
      "purchase", "refund", "in_app_purchase", "app_remove", "os_update", "app_update", "notification_receive"
    ],
    // steps of the purchase funnel, flagged so the BI can hide the obvious ones
    funnel_events: ["view_item", "add_to_cart", "view_cart", "begin_checkout", "add_shipping_info", "add_payment_info"]
  }
};
