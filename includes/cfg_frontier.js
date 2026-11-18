// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_frontier.js
//
// Knobs of the "frontier" models (tag: frontier): behavioural economics, queueing theory and
// statistical physics applied to the GA4 export. Questions that sit one step further than the
// labs (docs/frontier.md has the idea and the math of each one). Starting points for a mid size
// brazilian e-commerce, tune with your own numbers.

module.exports = {
  // prod_multi_tab_browsing: a page_view whose referrer is a page of the site but NOT the page
  // viewed right before it = the user went back to another tab (or used "open in new tab")
  multi_tab: {
    window_days: 30,
    // sessions with at least this many "parallel" views are multi tab sessions
    min_parallel_views: 2
  },

  // ecom_price_check_departures: the session ends on a product page and a new session of the
  // same person comes back to the SAME product within this window = went to check the price elsewhere
  price_check: {
    window_days: 60,
    max_return_hours: 48,
    // sessions with less engagement than this are bounces, not a price check
    min_session_engagement_sec: 10,
    min_departures: 20
  },

  // ecom_cart_filler_items: thresholds where the customer adds a cheap item to cross the line.
  // free_shipping_thresholds = the ones you KNOW (frete gratis acima de R$ X). empty = only auto detection
  cart_filler: {
    window_days: 120,
    free_shipping_thresholds: [199, 299],
    // the cart must be below the threshold by at most this share before the filler (ex: 0.25 = R$ 150 for R$ 199)
    max_gap_share: 0.25,
    // the filler cannot be more expensive than this share of the threshold
    max_filler_share: 0.35,
    min_events: 10
  },

  // ecom_cart_pipeline_forecast: carts as a sales pipeline (Little's law)
  cart_pipeline: {
    // history used to learn the conversion of a cart by its age
    learning_days: 120,
    // a cart older than this is dead
    max_cart_age_days: 30,
    forecast_horizon_days: 7
  },

  // ecom_variant_hunting: user opens many variants (size, color...) of the same product in one session
  variant_hunting: {
    window_days: 90,
    min_variants_viewed: 3,
    min_sessions: 20
  },

  // seg_price_watchers: user that keeps coming back to the same product without buying
  price_watch: {
    window_days: 45,
    min_view_days: 3,
    // the watcher is "hot" if the last view was this recent
    hot_days: 7
  },

  // ecom_choice_overload: distinct products viewed in the session vs conversion
  choice_overload: {
    window_days: 90,
    max_items_bucket: 30,
    min_sessions_per_bucket: 50
  },

  // ecom_price_anchoring: first price seen in the session relative to the category median
  price_anchoring: {
    window_days: 90,
    min_sessions: 50
  },

  // ecom_cart_indecision: add -> remove -> add again of the same item
  indecision: {
    window_days: 90,
    min_carts: 20
  },

  // mkt_viral_coefficient: share events and the new users that arrived from shared links
  viral: {
    window_days: 90,
    share_event_names: ["share"],
    // regex on session source / medium of NEW users that came from a shared link
    shared_link_pattern: "(whatsapp|wa\\.me|telegram|t\\.me|messenger|share|compartilh|indica|referral_link|sms)",
    // a new user arriving up to this many days after a share is credited to it
    attribution_days: 7
  },

  // mkt_language_geo_mismatch: device language that does not belong to the country
  language_geo: {
    window_days: 90,
    // expected language prefixes per country (GA4 geo_country names). others fall in "other_country"
    expected_languages: {
      Brazil: ["pt"],
      Portugal: ["pt"],
      "United States": ["en", "es"],
      Argentina: ["es"],
      Mexico: ["es"]
    },
    min_sessions: 30
  },

  // mkt_audience_affluence_index: purchasing power proxy from the device the visitor uses.
  // regex on LOWER(device_brand || ' ' || device_model). on the web GA4 often only says "iPhone" or
  // a frozen Android model, so the brand and the OS version carry most of the signal there
  affluence: {
    window_days: 90,
    premium_pattern: "(iphone 1[3-9]|iphone 2|pro max|galaxy s2[2-9]|galaxy s3|galaxy z|fold|flip|pixel [7-9]|pixel 1|ipad pro|macbook pro|xperia 1)",
    entry_pattern: "(galaxy a0|galaxy a1[0-4]|galaxy j|galaxy m1|moto e|moto g[0-9]?[0-9]? play|redmi [0-9]a|redmi a|positivo|multilaser|lenoxx|itel|tecno|alcatel)",
    // iOS major below this = old iPhone
    old_ios_major: 15,
    old_android_major: 10,
    min_sessions: 50
  },

  // prod_session_hazard_curve
  hazard: {
    window_days: 30,
    max_view_number: 30,
    max_minute: 60
  },

  // prod_zipf_long_tail: weekly fit of log(frequency) ~ log(rank)
  zipf: {
    weeks: 26,
    // only the top N ranks enter the fit (the very end of the tail is noise)
    max_rank: 2000,
    min_rank_points: 30
  },

  // biz_channel_dependency_risk
  dependency: {
    weeks: 52,
    // HHI above this = concentrated market of channels (DOJ guideline uses 0.25)
    concentrated_hhi: 0.25
  },

  // ds_session_narratives: one sentence per session, ready for an LLM, a CRM agent or a human
  narratives: {
    window_days: 14,
    max_items_in_text: 5
  }
};
