// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_project.js
//
// Business rules of the property. This is the file you will edit the most.
// Values below are for "Happy Store", a fake brazilian e-commerce, replace with yours.

module.exports = {
  site_name: "Happy Store",

  // brand terms, used to split Paid Search in Brand x Non-brand (campaign name or utm_term)
  brand_terms: ["happystore", "happy store", "happy-store", "happy_store"],

  // hostnames that are NOT production. ghost spam, staging leaking prod tag, google translate proxy...
  // regex fragments, matched against the hostname
  non_production_hostname_patterns: [
    "localhost", "127\\.0\\.0\\.1", "staging", "homolog", "^hml\\.", "^dev\\.", "^qa\\.", "preview",
    "vercel\\.app", "netlify\\.app", "translate\\.goog", "webcache\\.googleusercontent\\.com",
    "web\\.archive\\.org", "ngrok", "\\.local$", "github\\.io"
  ],

  // traffic_type values that mean "internal" (GA4 internal traffic rule)
  internal_traffic_types: ["internal", "developer", "dev", "qa", "interno"],

  // transaction ids that are obviously tests. the dev always tests in production at least once.
  test_transaction_patterns: ["test", "teste", "homolog", "^qa", "fake", "dummy", "sandbox"],

  // payment methods that create the order BEFORE the money arrives.
  // GA4 counts the purchase when the boleto is generated, but a lot of boletos are never paid.
  deferred_payment_patterns: ["boleto", "bank_slip", "billet", "bankslip", "pix"],
  // when the CRM module is off we use these historical paid rates to estimate real revenue.
  // ask finance for yours, these are just "mercado" numbers.
  expected_paid_rate: { boleto: 0.55, pix: 0.9, default: 0.98 },

  // max realistic order value, above this is flagged as outlier for sure (in property currency)
  max_realistic_order_value: 50000,

  // gross margin used in unit economics (LTV / CAC, payback). ask finance, 40% is a guess
  assumed_gross_margin: 0.4,

  bot: {
    // datacenter cities that show up a lot in bot traffic. dont put brazilian cities here,
    // real people live in Osasco too :)
    datacenter_cities: [
      "Ashburn", "Boardman", "Council Bluffs", "The Dalles", "Des Moines", "Moncks Corner",
      "Lenoir", "Pryor", "Quincy", "Moses Lake", "Santa Clara", "Hillsboro", "Hilliard",
      "Prineville", "Forest City", "Altoona", "Sterling", "Manassas", "Lanzhou", "Zhengzhou"
    ],
    max_events_per_minute: 120,
    // score >= this means "probably a bot" (0-100)
    min_score_to_flag: 60,

    // "one and done": NEW device (first_visit / first_open), ONE page path (url params ignored)
    // or ONE app screen and class, no engaged session, not an active user for GA4, no key event,
    // no purchase. Bots that drop the cookie look exactly like this... and so does a real person
    // that opened the site and left. That is why it weighs 30: alone it never flags (60 needed),
    // it only tips the scale when another signal fires together
    one_and_done_weight: 30,

    // device level (int_ga4__device_bot_signals): the behaviour of the user_pseudo_id in the
    // last N days, not one session alone
    device: {
      window_days: 90,
      // new session in ANOTHER country less than this after the previous one ended = teleport.
      // VPN and iCloud Private Relay change country too, that is why one jump alone weighs little
      impossible_travel_hours: 2,
      max_countries_per_week: 3,
      // patterns only make sense with some sessions
      min_sessions_for_patterns: 6,
      // coefficient of variation of the time between sessions. a cron job is very regular
      max_gap_cv_for_robot: 0.1,
      // share of sessions without any engagement time
      zero_engagement_share: 0.9,
      // median session of 2 seconds or less
      blink_session_seconds: 2,
      // many people logging in the same device = credential stuffing or a test rig
      max_user_ids_per_device: 5,
      // share of sessions between 1h and 5h (local time)
      night_share: 0.8,
      // Chrome / Edge / Firefox this many major versions behind the current one (they auto update)
      outdated_browser_major_gap: 20,
      // share of page views on 404 pages (vulnerability scanners walk /wp-admin, /.env...)
      not_found_share: 0.5,
      headless_browser_pattern: "headless|phantom|selenium|puppeteer|playwright|webdriver|crawler|spider|bot\\b"
    }
  },

  // page type classification, first match wins. regex on page_path (lower case, no query string)
  page_types: [
    { type: "home", pattern: "^/$|^/(index\\.html?|home|inicio)$" },
    { type: "thank_you", pattern: "(obrigado|thank-?you|pedido-confirmado|order-?confirmation|orderplaced|checkout/success)" },
    { type: "checkout", pattern: "^/(checkout|finalizar|pagamento|payment|identificacao|onepage)" },
    { type: "cart", pattern: "^/(carrinho|cart|sacola|bag|checkout/cart)" },
    { type: "search", pattern: "^/(busca|search|pesquisa|s)(/|$)" },
    { type: "product", pattern: "(/p$|/p/|/produto/|/product/|/products/|-p-\\d+|/dp/)" },
    { type: "category", pattern: "^/(c|categoria|categorias|category|departamento|colecao|colecoes|collections|loja)(/|$)" },
    { type: "account", pattern: "^/(minha-conta|my-account|account|conta|login|cadastro|signup|entrar|meus-pedidos)" },
    { type: "blog", pattern: "^/(blog|artigos|conteudo|news|noticias|dicas)(/|$)" },
    { type: "institutional", pattern: "^/(sobre|about|contato|contact|fale-conosco|politica|privacidade|privacy|termos|terms|faq|ajuda|help|trocas|devolucao|lojas|nossas-lojas)" },
    { type: "landing_page", pattern: "^/(lp|landing|promo|promocao|ofertas|black-friday|campanha)(/|$)" }
  ],

  // page_title fragments that mean 404 (accents removed before matching)
  not_found_title_patterns: ["404", "not found", "nao encontrad", "pagina inexistente", "page not found", "ops! pagina", "erro 404"],

  // product features to measure adoption (prod_feature_adoption)
  features: [
    { feature: "site_search", event_name: "view_search_results" },
    { feature: "wishlist", event_name: "add_to_wishlist" },
    { feature: "share", event_name: "share" },
    { feature: "login", event_name: "login" },
    { feature: "sign_up", event_name: "sign_up" },
    { feature: "video", event_name: "video_start" },
    { feature: "file_download", event_name: "file_download" },
    { feature: "newsletter", event_name: "generate_lead" },
    { feature: "product_reviews", event_name: "view_reviews" },
    { feature: "size_guide", event_name: "view_size_guide" }
  ],

  // web vitals, if you use the web-vitals lib sending to GA4 (event per metric or one event)
  web_vitals: {
    event_names: ["LCP", "CLS", "INP", "FCP", "TTFB", "web_vitals"],
    metric_name_param: "metric_name",
    value_param: "metric_value",
    rating_param: "metric_rating"
  },

  // UA migration: sites that kept sending UA style params on GA4 events
  ua_event_params: { category: "event_category", action: "event_action", label: "event_label" },

  // site search: param with the number of results, if your search sends it (zero results report)
  search_results_count_param: "search_results_count",

  // app crash event (Firebase)
  app_crash_event: "app_exception",

  // BigQuery costs (ops_job_costs). on demand price of your region, in USD per TiB scanned.
  // with slots / editions the bytes still tell you who is heavy, ignore the dollars
  bigquery: {
    on_demand_usd_per_tib: 6.25,
    jobs_history_days: 30,
    // a table nobody queried in this many days shows up as a candidate to switch off
    unused_after_days: 60
  }
};
