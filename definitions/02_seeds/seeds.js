// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Reference tables built from the includes/cfg_*.js files.
// Change the config, the table follows on the next run. No CSV lost in someone's Drive.

const seedConfig = (name, description, extra = {}) => Object.assign({
  type: "table",
  schema: constants.SCHEMAS.seeds,
  description,
  tags: ["seeds", "daily"]
}, extra);

// ------------------------------------------------------------------ Brazil
publish("seed_br_states", seedConfig("Brazilian states (UF) with macro region, capital and IBGE Censo 2022 population"))
  .query(ctx => helpers.seedSql([
    { name: "uf", type: "STRING" },
    { name: "state_name", type: "STRING" },
    { name: "ga4_region", type: "STRING" },
    { name: "macro_region", type: "STRING" },
    { name: "capital", type: "STRING" },
    { name: "ibge_code", type: "INT64" },
    { name: "population_2022", type: "INT64" }
  ], seeds_br.states));

publish("seed_pt_stopwords", seedConfig("Portuguese stopwords (without accents) for site search text mining"))
  .query(ctx => helpers.seedSql([{ name: "word", type: "STRING" }], Array.from(new Set(seeds_br.stopwords_pt)).map(word => ({ word }))));

// ------------------------------------------------------------------ channels
const sourceCategories = [];
const addCategory = (list, category) => list.forEach(source => sourceCategories.push({ source, category }));
addCategory(cfg_channels.search, "search");
addCategory(cfg_channels.social, "social");
addCategory(cfg_channels.video, "video");
addCategory(cfg_channels.shopping, "shopping");
addCategory(cfg_channels.marketplaces, "marketplace");
addCategory(cfg_channels.ai_assistants, "ai_assistant");
addCategory(cfg_channels.payment_gateways, "payment_gateway");
addCategory(cfg_channels.cashback_coupons, "cashback_coupon");
addCategory(cfg_channels.whatsapp, "whatsapp");

publish("seed_source_categories", seedConfig("Source -> category list used by the channel grouping (GA4 source categories + brazilian sites)"))
  .query(ctx => helpers.seedSql([{ name: "source", type: "STRING" }, { name: "category", type: "STRING" }], sourceCategories));

publish("seed_bot_datacenter_cities", seedConfig("Cities of big datacenters, used as one of the bot signals"))
  .query(ctx => helpers.seedSql([{ name: "city", type: "STRING" }], cfg_project.bot.datacenter_cities.map(city => ({ city }))));

publish("seed_page_types", seedConfig("Page type rules (regex on page_path, first match wins)"))
  .query(ctx => helpers.seedSql(
    [{ name: "priority", type: "INT64" }, { name: "page_type", type: "STRING" }, { name: "pattern", type: "STRING" }],
    cfg_project.page_types.map((p, i) => ({ priority: i + 1, page_type: p.type, pattern: p.pattern }))
  ));

// ------------------------------------------------------------------ business config
publish("seed_key_events", seedConfig("Key events configured in cfg_key_events.js"))
  .query(ctx => helpers.seedSql([
    { name: "key_event_name", type: "STRING" },
    { name: "event_name", type: "STRING" },
    { name: "label", type: "STRING" },
    { name: "category", type: "STRING" },
    { name: "counting", type: "STRING" },
    { name: "value_rule", type: "STRING" },
    { name: "fixed_value", type: "FLOAT64" },
    { name: "has_condition", type: "BOOL" },
    { name: "is_primary", type: "BOOL" },
    { name: "google_ads_conversion_name", type: "STRING" },
    { name: "meta_event_name", type: "STRING" }
  ], cfg_key_events.key_events.map(k => ({
    key_event_name: k.name,
    event_name: k.event_name,
    label: k.label,
    category: k.category || null,
    counting: k.counting || "every_event",
    value_rule: k.value || "none",
    fixed_value: k.fixed_value || null,
    has_condition: Boolean(k.condition),
    is_primary: Boolean(k.is_primary),
    google_ads_conversion_name: k.google_ads_conversion_name || null,
    meta_event_name: k.meta_event_name || null
  }))));

publish("seed_promotions", seedConfig("Promotion calendar (cfg_promotions.js)"))
  .query(ctx => helpers.seedSql([
    { name: "promo_id", type: "STRING" },
    { name: "promo_name", type: "STRING" },
    { name: "promo_type", type: "STRING" },
    { name: "start_date", type: "DATE" },
    { name: "end_date", type: "DATE" },
    { name: "coupon_codes", type: "ARRAY<STRING>" },
    { name: "discount_pct", type: "FLOAT64" }
  ], cfg_promotions.promotions.map(p => ({
    promo_id: p.promo_id,
    promo_name: p.name,
    promo_type: p.promo_type,
    start_date: p.start_date,
    end_date: p.end_date,
    coupon_codes: (p.coupon_codes || []).map(c => c.toUpperCase()),
    discount_pct: p.discount_pct
  }))));

publish("seed_monthly_targets", seedConfig("Monthly business targets (cfg_targets.js)"))
  .query(ctx => helpers.seedSql([
    { name: "target_month", type: "DATE" },
    { name: "revenue", type: "FLOAT64" },
    { name: "transactions", type: "FLOAT64" },
    { name: "sessions", type: "FLOAT64" },
    { name: "new_customers", type: "FLOAT64" }
  ], cfg_targets.monthly_targets.map(t => ({
    target_month: t.month,
    revenue: t.revenue,
    transactions: t.transactions,
    sessions: t.sessions,
    new_customers: t.new_customers
  }))));

publish("seed_manual_costs", seedConfig("Manual monthly marketing costs (influencers, affiliates, agencies...) from cfg_costs.js"))
  .query(ctx => helpers.seedSql([
    { name: "cost_month", type: "DATE" },
    { name: "platform", type: "STRING" },
    { name: "source", type: "STRING" },
    { name: "medium", type: "STRING" },
    { name: "campaign", type: "STRING" },
    { name: "cost", type: "FLOAT64" }
  ], cfg_costs.manual_costs));

// ------------------------------------------------------------------ tracking plan
const planRows = [];
cfg_tracking_plan.events.forEach(e => {
  const params = e.params || [];
  if (params.length === 0) {
    planRows.push({ event_name: e.event_name, owner: e.owner || null, param_name: null, param_type: null, is_required: false, requires_items: Boolean(e.requires_items) });
  }
  params.forEach(p => planRows.push({
    event_name: e.event_name,
    owner: e.owner || null,
    param_name: p.name,
    param_type: p.type,
    is_required: Boolean(p.required),
    requires_items: Boolean(e.requires_items)
  }));
});

publish("seed_tracking_plan", seedConfig("Tracking plan as a table, one row per event x param (cfg_tracking_plan.js)"))
  .query(ctx => helpers.seedSql([
    { name: "event_name", type: "STRING" },
    { name: "owner", type: "STRING" },
    { name: "param_name", type: "STRING" },
    { name: "param_type", type: "STRING" },
    { name: "is_required", type: "BOOL" },
    { name: "requires_items", type: "BOOL" }
  ], planRows));

publish("seed_automatic_events", seedConfig("GA4 automatic / enhanced measurement events, never flagged as unplanned"))
  .query(ctx => helpers.seedSql([{ name: "event_name", type: "STRING" }], cfg_tracking_plan.automatic_events.map(event_name => ({ event_name }))));

// ------------------------------------------------------------------ lifts
publish("seed_lift_interventions", seedConfig("Dated changes measured by lift_interventions (cfg_lifts.js)"))
  .query(ctx => helpers.seedSql([
    { name: "intervention_name", type: "STRING" },
    { name: "description", type: "STRING" },
    { name: "start_date", type: "DATE" },
    { name: "end_date", type: "DATE" },
    { name: "pre_days", type: "INT64" },
    { name: "post_days", type: "INT64" },
    { name: "metrics", type: "ARRAY<STRING>" },
    { name: "segment_dimension", type: "STRING" },
    { name: "segment_value", type: "STRING" },
    { name: "control_dimension", type: "STRING" },
    { name: "control_value", type: "STRING" }
  ], cfg_lifts.interventions.map(i => ({
    intervention_name: i.name,
    description: i.description || null,
    start_date: i.start_date,
    end_date: i.end_date || null,
    pre_days: i.pre_days || 56,
    post_days: i.post_days || 28,
    metrics: i.metrics || ["conversion_rate", "revenue"],
    segment_dimension: i.segment ? i.segment.dimension : null,
    segment_value: i.segment ? String(i.segment.value) : null,
    control_dimension: i.control ? i.control.dimension : null,
    control_value: i.control ? String(i.control.value) : null
  }))));

// ------------------------------------------------------------------ experiments
publish("seed_ab_tests", seedConfig("A/B tests registry (cfg_experiments.js)"))
  .query(ctx => helpers.seedSql([
    { name: "experiment_id", type: "STRING" },
    { name: "experiment_name", type: "STRING" },
    { name: "control_variant", type: "STRING" },
    { name: "expected_split", type: "FLOAT64" },
    { name: "goal_key_event", type: "STRING" },
    { name: "start_date", type: "DATE" },
    { name: "end_date", type: "DATE" }
  ], cfg_experiments.ab_tests.map(t => ({
    experiment_id: t.experiment_id,
    experiment_name: t.name,
    control_variant: t.control_variant,
    expected_split: t.expected_split,
    goal_key_event: t.goal_key_event,
    start_date: t.start_date,
    end_date: t.end_date
  }))));

publish("seed_geo_experiments", seedConfig("Geo experiments by brazilian state (cfg_experiments.js)"))
  .query(ctx => helpers.seedSql([
    { name: "experiment_id", type: "STRING" },
    { name: "experiment_name", type: "STRING" },
    { name: "test_ufs", type: "ARRAY<STRING>" },
    { name: "control_ufs", type: "ARRAY<STRING>" },
    { name: "pre_start", type: "DATE" },
    { name: "pre_end", type: "DATE" },
    { name: "test_start", type: "DATE" },
    { name: "test_end", type: "DATE" }
  ], cfg_experiments.geo_experiments.map(g => ({
    experiment_id: g.experiment_id,
    experiment_name: g.name,
    test_ufs: g.test_ufs,
    control_ufs: g.control_ufs,
    pre_start: g.pre_start,
    pre_end: g.pre_end,
    test_start: g.test_start,
    test_end: g.test_end
  }))));

// ------------------------------------------------------------------ LGPD
if (!constants.PRIVACY.dsr_table) {
  publish("seed_data_subject_requests", seedConfig("LGPD data subject requests from cfg_privacy.js (use var dsr_table in production)"))
    .query(ctx => helpers.seedSql([
      { name: "request_id", type: "STRING" },
      { name: "request_type", type: "STRING" },
      { name: "user_id", type: "STRING" },
      { name: "user_pseudo_id", type: "STRING" },
      { name: "requested_at", type: "DATE" },
      { name: "status", type: "STRING" }
    ], cfg_privacy.data_subject_requests));
}
