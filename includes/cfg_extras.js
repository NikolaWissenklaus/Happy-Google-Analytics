// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_extras.js
//
// Business rules of the "extras" pack: the new GA4 UI replicas (lead generation, enhanced
// measurement), the cross data marts (calendar x media, launches, wishlist, regional
// bestsellers, events playbook, first category LTV, brand cannibalization, identified users)
// and the vertical marts (banking, streaming, news paywall, travel). Same rule of the project:
// the SQL reads this file, it never hardcodes an event name or a threshold.
//
// Every vertical block has `enabled`. When it is false the model is disabled, so a store that
// does not send streaming events does not get an empty table. Event names are the GA4
// recommended ones when they exist, rename them to what your tag sends.

module.exports = {
  // ---------------------------------------------------------------- GA4 UI: Generate leads
  // GA4 Business objectives > Generate leads (Lead acquisition / Lead disqualification and conversion)
  // https://support.google.com/analytics/answer/12944921 (recommended lead events)
  lead_events: {
    generate: "generate_lead",
    qualify: "qualify_lead",
    disqualify: "disqualify_lead",
    working: "working_lead",
    close_convert: "close_convert_lead",
    close_unconvert: "close_unconvert_lead"
  },
  // params that carry the reason / source of the lead (GA4 recommended names)
  lead_params: {
    source: "lead_source",
    status: "lead_status",
    disqualified_reason: "disqualified_lead_reason",
    unconvert_reason: "unconvert_lead_reason"
  },

  // ---------------------------------------------------------------- GA4 UI: enhanced measurement
  // how many days the enhanced measurement replica keeps (it is an event level scan)
  enhanced_measurement_days: 90,

  // ---------------------------------------------------------------- calendar x media
  // a special day only enters the comparison with at least this cost on the day
  calendar_media_min_daily_cost: 50,

  // ---------------------------------------------------------------- launch cannibalization
  launch: {
    // a product is a "launch" when its first view is inside this window
    lookback_days: 180,
    // days before / after the launch that are compared
    window_days: 28,
    // ignore launches that did not sell at least this in the window after
    min_units_after: 5
  },

  // ---------------------------------------------------------------- wishlist
  wishlist: {
    event_name: "add_to_wishlist",
    // a wishlist add "converts" when the same user buys the same item within this many days
    conversion_window_days: 60,
    min_adds_per_item: 10
  },

  // ---------------------------------------------------------------- regional bestsellers
  regional: {
    // location quotient only for UF x category with at least this many units
    min_units: 20,
    // LQ >= this = the category sells much more in the UF than in Brazil
    over_index: 1.3,
    under_index: 0.7
  },

  // ---------------------------------------------------------------- upcoming events playbook
  playbook: {
    // how far ahead the playbook looks for special days in dim_calendar
    days_ahead: 120,
    // days before the event that count as the "warm up" of the event
    warm_up_days: 14
  },

  // ---------------------------------------------------------------- first category LTV
  first_category: {
    // horizons of the LTV (days after the first purchase)
    horizons: [30, 90, 180],
    min_customers: 30
  },

  // ---------------------------------------------------------------- brand cannibalization
  // brand sessions = Paid Search with a brand campaign / term + Organic Search landing on these page types
  brand_organic_landing_types: ["home"],

  // ---------------------------------------------------------------- verticals
  // banking, fintech, insurance, telecom: any "simulate -> apply -> approved" flow
  banking: {
    enabled: false,
    // ordered steps of the application funnel. condition is optional SQL over stg_ga4__events
    steps: [
      { name: "simulate", event_name: "simulation_complete" },
      { name: "start_application", event_name: "application_start" },
      { name: "submit_application", event_name: "application_submit" },
      { name: "approved", event_name: "application_approved" }
    ],
    // param with the product of the flow (credit_card, personal_loan, account, insurance...)
    product_param: "product_type",
    // param with the requested / simulated amount
    amount_param: "value",
    // amount bands in property currency
    amount_bands: [1000, 5000, 20000, 100000]
  },

  // streaming, video on demand, podcasts, online courses with video
  streaming: {
    enabled: false,
    play_event: "video_start",
    progress_event: "video_progress",
    complete_event: "video_complete",
    // param with the title / episode (video_title of the enhanced measurement by default)
    title_param: "video_title",
    // param with the series / show (leave null when there is none)
    series_param: "content_series",
    // events that mean the user started paying
    subscribe_events: ["purchase", "subscribe", "start_subscription"],
    // a session with this many distinct titles started is a binge session
    binge_min_titles: 3
  },

  // news, magazines, any paywall / meter
  news_paywall: {
    enabled: false,
    // event fired when the paywall is shown (or the meter blocks the article)
    paywall_event: "paywall_view",
    subscribe_events: ["purchase", "subscribe", "sign_up"],
    newsletter_event: "newsletter_signup",
    // page types of dim_pages / landing_page_type that are articles
    article_page_types: ["article", "blog", "content"],
    // content_group or path_level_1 is the section of the article
    section_from: "content_group"
  },

  // travel, hotels, airlines, bus tickets, events with a date
  travel: {
    enabled: false,
    search_event: "search",
    // params of the search (GA4 recommended travel params when they exist)
    origin_param: "origin",
    destination_param: "destination",
    start_date_param: "start_date",
    end_date_param: "end_date",
    booking_event: "purchase",
    // lead time bands in days (search date -> trip date)
    lead_time_bands: [3, 7, 14, 30, 60, 120]
  }
};
