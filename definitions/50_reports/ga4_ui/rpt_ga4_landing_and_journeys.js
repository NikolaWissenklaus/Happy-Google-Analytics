// author: Francisco Lucas / Nikola Wissenklaus / Chico

// GA4 Reports > Engagement > Landing page, and the two ecommerce journeys of Reports > Monetization.
// Built on fct_sessions like the other replicas (bots kept, numbers comparable with the UI).

const schema = constants.SCHEMAS.reports_ga4;

reports.incrementalReport({
  name: "rpt_ga4_landing_pages_daily",
  schema,
  description: "GA4 Reports > Engagement > Landing page: sessions, users, new users, engagement, key events and revenue per landing page (exactly the GA4 one: first page_view, '(not set)' when there is none)",
  flavor: "ga4",
  dims: [
    { expr: "COALESCE(s.landing_page_path_ga4, '(not set)')", alias: "landing_page" },
    { expr: "s.landing_page_type", alias: "landing_page_type" }
  ]
});

// journeys: open funnel per session (same as the GA4 reports, which are not closed funnels)
function journeyReport(name, description, steps) {
  publish(name, {
    type: "incremental",
    schema,
    description,
    bigquery: { partitionBy: "session_date", labels: { layer: "reports", flavor: "ga4" } },
    tags: ["reports", "ga4_report", "daily", "ecommerce"]
  })
    .preOps(ctx => helpers.incrementalPreOps({
      self: ctx.self(), incremental: ctx.incremental(), model: name, dateColumn: "session_date",
      watermarks: ctx.ref("ops_incremental_watermarks"), upstream: metrics.SESSION_UPSTREAM
    }))
    .query(ctx => `
SELECT
  session_date,
  COALESCE(device_category, '(not set)') AS device_category,
  IF(is_new_user, 'new', 'returning') AS user_type,
  ${steps.map(s => `COUNTIF(${s.flag}) AS sessions_${s.name},
  HLL_COUNT.INIT(IF(${s.flag}, user_pseudo_id, NULL)) AS users_${s.name}_hll`).join(",\n  ")},
  ${steps.slice(1).map((s, i) => `SAFE_DIVIDE(COUNTIF(${s.flag}), COUNTIF(${steps[i].flag})) AS rate_${steps[i].name}_to_${s.name}`).join(",\n  ")},
  ${steps.slice(1).map((s, i) => `1 - SAFE_DIVIDE(COUNTIF(${s.flag}), COUNTIF(${steps[i].flag})) AS abandonment_after_${steps[i].name}`).join(",\n  ")},
  CURRENT_TIMESTAMP() AS loaded_at
FROM ${ctx.ref("fct_sessions")}
WHERE session_date >= run_from
GROUP BY 1, 2, 3`)
    .postOps(ctx => helpers.incrementalPostOps({ incremental: ctx.incremental(), model: name, watermarks: ctx.ref("ops_incremental_watermarks") }));
}

journeyReport(
  "rpt_ga4_purchase_journey_daily",
  "GA4 Reports > Monetization > Purchase journey: session start -> view product -> add to cart -> begin checkout -> purchase, sessions and users per step with abandonment, by device and new/returning",
  [
    { name: "session_start", flag: "TRUE" },
    { name: "view_item", flag: "has_view_item" },
    { name: "add_to_cart", flag: "has_add_to_cart" },
    { name: "begin_checkout", flag: "has_begin_checkout" },
    { name: "purchase", flag: "has_purchase" }
  ]
);

journeyReport(
  "rpt_ga4_checkout_journey_daily",
  "GA4 Reports > Monetization > Checkout journey: begin checkout -> add shipping -> add payment -> purchase, by device and new/returning",
  [
    { name: "begin_checkout", flag: "has_begin_checkout" },
    { name: "add_shipping_info", flag: "has_add_shipping_info" },
    { name: "add_payment_info", flag: "has_add_payment_info" },
    { name: "purchase", flag: "has_purchase" }
  ]
);
