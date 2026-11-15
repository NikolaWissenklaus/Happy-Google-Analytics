// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_experiments.js
//
// A/B tests and geo experiments.
//
// A/B: the site sends an exposure event (ex: experiment_impression) with the experiment
// and the variant as params. Works with VWO, Optimizely, AB Tasty, GrowthBook, homemade...
// as long as the exposure arrives in GA4. cro_ab_test_results does the math:
// conversion per variant, uplift, z-test, Wilson intervals, SRM check and P(B > A).
//
// Geo: region based tests (ex: TV only in PR and SC). ds_geo_experiment_did reads
// GA4 by UF and computes difference-in-differences against the control states.

module.exports = {
  exposure: {
    event_name: "experiment_impression",
    experiment_param: "experiment_id",
    variant_param: "variant_id"
  },

  ab_tests: [
    {
      experiment_id: "exp_checkout_onepage",
      name: "One page checkout vs 3 steps",
      control_variant: "0",
      expected_split: 0.5,
      goal_key_event: "purchase",
      start_date: "2026-09-01",
      end_date: "2026-10-15"
    },
    {
      experiment_id: "exp_pdp_frete",
      name: "Shipping calculator above the fold on product page",
      control_variant: "0",
      expected_split: 0.5,
      goal_key_event: "purchase",
      start_date: "2026-10-01",
      end_date: null
    }
  ],

  geo_experiments: [
    {
      experiment_id: "geo_tv_sul_2026",
      name: "Regional TV in PR and SC",
      test_ufs: ["PR", "SC"],
      control_ufs: ["RS", "MG", "GO"],
      pre_start: "2026-07-01",
      pre_end: "2026-08-31",
      test_start: "2026-09-01",
      test_end: "2026-09-30"
    }
  ]
};
