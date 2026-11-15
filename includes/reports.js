// author: Francisco Lucas / Nikola Wissenklaus / Chico

// reports.js
//
// Builder for the "dimension x standard metrics" reports of the GA4 UI and of the old
// Universal Analytics. Every report becomes a daily incremental table (date x dimensions)
// with additive metrics + HLL sketches, so any date range can be rebuilt in the BI tool.
//
// These replicas keep bots on purpose (the GA4 UI also shows them, GA4 only filters the
// IAB known bots). That is the only way the numbers match the interface.

const constants = require("./constants");
const helpers = require("./helpers");
const metrics = require("./metrics");

// GA4 UI metric names, same definitions of the GA4 docs.
// always qualified with the fct_sessions alias, the reports can join other tables
function ga4Metrics(p = "s.") {
  return `COUNT(*) AS sessions,
    COUNT(DISTINCT ${p}user_pseudo_id) AS total_users,
    HLL_COUNT.INIT(${p}user_pseudo_id) AS total_users_hll,
    COUNT(DISTINCT IF(${metrics.activeUser(p)}, ${p}user_pseudo_id, NULL)) AS active_users,
    HLL_COUNT.INIT(IF(${metrics.activeUser(p)}, ${p}user_pseudo_id, NULL)) AS active_users_hll,
    COUNTIF(${p}is_new_user) AS new_users,
    COUNTIF(${p}is_engaged_ga4) AS engaged_sessions,
    SUM(${p}engagement_time_sec) AS user_engagement_sec,
    SUM(${p}event_count) AS event_count,
    SUM(${p}page_views + ${p}screen_views) AS views,
    SUM(${p}key_events) AS key_events,
    COUNTIF(${p}has_key_event) AS sessions_with_key_event,
    SUM(${p}transactions) AS ecommerce_purchases,
    SUM(${p}revenue) AS total_revenue`;
}

function ga4Ratios() {
  return `SAFE_DIVIDE(engaged_sessions, sessions) AS engagement_rate,
    1 - SAFE_DIVIDE(engaged_sessions, sessions) AS bounce_rate,
    SAFE_DIVIDE(engaged_sessions, active_users) AS engaged_sessions_per_user,
    SAFE_DIVIDE(user_engagement_sec, sessions) AS average_engagement_time_per_session,
    SAFE_DIVIDE(user_engagement_sec, active_users) AS average_engagement_time,
    SAFE_DIVIDE(event_count, sessions) AS events_per_session,
    SAFE_DIVIDE(views, active_users) AS views_per_user,
    SAFE_DIVIDE(sessions_with_key_event, sessions) AS session_key_event_rate`;
}

function uaMetrics() {
  return metrics.uaMetrics("s");
}

function uaRatios() {
  return metrics.uaRatios();
}

// dims: [{ expr: "session_default_channel_group", alias: "session_default_channel_group" }]
// joins: extra SQL after FROM (ex: join dim_users for first user dimensions)
function dailyReportSql({ ctx, name, dims, flavor = "ga4", joins = "", where = "" }) {
  const selectList = ["s.session_date"].concat(dims.map(d => `${d.expr} AS ${d.alias}`));
  const groupBy = [1].concat(dims.map((d, i) => i + 2)).join(", ");
  const m = flavor === "ga4" ? ga4Metrics() : uaMetrics();
  const r = flavor === "ga4" ? ga4Ratios() : uaRatios();
  return `
WITH aggregated AS (
  SELECT
    ${selectList.join(",\n    ")},
    ${m}
  FROM ${ctx.ref("fct_sessions")} AS s
  ${joins}
  WHERE s.session_date >= run_from
    ${where}
  GROUP BY ${groupBy}
)

SELECT
  *,
  ${r},
  CURRENT_TIMESTAMP() AS loaded_at
FROM aggregated`;
}

function incrementalReport({ name, schema, description, dims, flavor, joins, where, tags = [] }) {
  return publish(name, {
    type: "incremental",
    schema,
    description,
    bigquery: {
      partitionBy: "session_date",
      labels: { layer: "reports", flavor }
    },
    tags: ["reports", flavor === "ga4" ? "ga4_report" : "ua_report", "daily"].concat(tags)
  })
    .preOps(ctx => helpers.incrementalPreOps({
      self: ctx.self(),
      incremental: ctx.incremental(),
      model: name,
      dateColumn: "session_date",
      watermarks: ctx.ref("ops_incremental_watermarks"),
      upstream: metrics.SESSION_UPSTREAM
    }))
    .query(ctx => dailyReportSql({ ctx, name, dims, flavor, joins: typeof joins === "function" ? joins(ctx) : (joins || ""), where: where || "" }))
    .postOps(ctx => helpers.incrementalPostOps({ incremental: ctx.incremental(), model: name, watermarks: ctx.ref("ops_incremental_watermarks") }));
}

module.exports = { ga4Metrics, ga4Ratios, uaMetrics, uaRatios, dailyReportSql, incrementalReport };
