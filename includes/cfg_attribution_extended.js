// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_attribution_extended.js
//
// Knobs of the extra attribution models (tag: attribution_extended). The original 7 rule based
// models, Markov and Shapley stay exactly as they are; these ones sit next to them
// (docs/attribution_extended.md has the idea and the math of each one).

module.exports = {
  // window (days of conversions / journeys) of the data driven models
  window_days: 90,

  // channels whose touch counts as "paid" for the last paid click model (regex on the GA4
  // default channel group of the session, no carry over)
  paid_channel_pattern: "^(Paid|Display|Cross-network|Audio)",

  // learned time decay: the half life is the median age of the assisting touches, inside these bounds
  learned_half_life_bounds_days: [0.5, 30],

  // geometric position model: each step back from the conversion keeps this share of the credit
  geometric_ratio: 0.5,

  // attr_user_journeys: non converting journeys keep at most this many touches (the newest ones)
  max_touches_per_journey: 20,

  // Shao and Li probabilistic model + synergy: a channel (or a pair) needs this many journeys
  min_journeys_per_channel: 100,
  min_journeys_per_pair: 50,

  // higher order Markov: orders to fit (1 = the classic model, to compare)
  markov_orders: [1, 2, 3],
  markov_max_path_length: 12,
  markov_max_distinct_paths: 50000,

  // additive hazard (survival) model: half lives tried for the decay of the effect of a touch
  // (the best one by likelihood wins), EM iterations, and the journeys sampled into the JS UDF
  hazard: {
    half_life_grid_days: [0.25, 0.5, 1, 2, 4, 7, 14, 30],
    iterations: 150,
    max_converting_journeys: 40000,
    max_non_converting_journeys: 40000
  },

  // BQML logistic regression on the touch counts per channel (only with enable_bqml)
  logistic: {
    l2_reg: 1.0,
    // touches per channel above this are capped (the 30th email does not add information)
    max_touches_per_channel: 10,
    // GA4 default channel groups used as features. Anything else becomes "other"
    channels: [
      "Direct", "Organic Search", "Paid Search", "Organic Social", "Paid Social", "Email", "Referral",
      "Organic Video", "Paid Video", "Display", "Paid Shopping", "Organic Shopping", "Affiliates",
      "Cross-network", "SMS", "Audio", "Mobile Push Notifications", "Paid Other", "Unassigned"
    ]
  }
};
