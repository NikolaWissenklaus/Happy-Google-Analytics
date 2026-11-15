// author: Francisco Lucas / Nikola Wissenklaus / Chico

// metrics.js
//
// Standard metric blocks over fct_sessions, so "sessions", "engagement rate", "conversion
// rate"... mean exactly the same thing in every mart and report. If the business changes
// a definition, it changes here and only here.
//
// users_hll / active_users_hll are HLL sketches: to count users of a period, use
// HLL_COUNT.MERGE(users_hll). SUM(users) over days counts the same person many times.

const constants = require("./constants");

// upstream incremental models behind fct_sessions (for the auto backfill of the daily marts)
const SESSION_UPSTREAM = ["int_ga4__sessions_base", "int_ga4__session_traffic", "int_ga4__transactions", "int_ga4__key_events"];

// GA4 "active user": engaged session, first visit or some engagement time
function activeUser(p = "") {
  return `(${p}is_engaged OR ${p}is_new_user OR ${p}engagement_time_msec > 0)`;
}
const ACTIVE_USER = activeUser();

function sessionMetrics(alias = "") {
  const p = alias ? `${alias}.` : "";
  return `COUNT(*) AS sessions,
    COUNT(DISTINCT ${p}user_pseudo_id) AS total_users,
    COUNT(DISTINCT IF(${activeUser(p)}, ${p}user_pseudo_id, NULL)) AS active_users,
    HLL_COUNT.INIT(${p}user_pseudo_id) AS users_hll,
    HLL_COUNT.INIT(IF(${activeUser(p)}, ${p}user_pseudo_id, NULL)) AS active_users_hll,
    COUNTIF(${p}is_new_user) AS new_users,
    COUNTIF(${p}is_engaged) AS engaged_sessions,
    SUM(${p}engagement_time_sec) AS engagement_time_sec,
    SUM(${p}page_views + ${p}screen_views) AS views,
    SUM(${p}event_count) AS events,
    SUM(${p}key_events) AS key_events,
    COUNTIF(${p}has_key_event) AS sessions_with_key_event,
    SUM(${p}transactions) AS transactions,
    SUM(${p}revenue) AS revenue,
    COUNTIF(${p}has_purchase) AS sessions_with_purchase`;
}

// ratios that can be recalculated from the sums above (never average the ratios!)
function sessionRatios() {
  return `SAFE_DIVIDE(engaged_sessions, sessions) AS engagement_rate,
    SAFE_DIVIDE(transactions, sessions) AS conversion_rate,
    SAFE_DIVIDE(sessions_with_key_event, sessions) AS key_event_rate,
    SAFE_DIVIDE(revenue, transactions) AS average_order_value,
    SAFE_DIVIDE(revenue, sessions) AS revenue_per_session,
    SAFE_DIVIDE(engagement_time_sec, sessions) AS avg_engagement_time_per_session,
    SAFE_DIVIDE(views, sessions) AS views_per_session`;
}

// UA style metrics (bounce rate, avg session duration, pages per session, % new sessions)
function uaMetrics(alias = "") {
  const p = alias ? `${alias}.` : "";
  return `COUNT(*) AS sessions,
    COUNT(DISTINCT ${p}user_pseudo_id) AS users,
    HLL_COUNT.INIT(${p}user_pseudo_id) AS users_hll,
    COUNTIF(${p}is_new_user) AS new_users,
    COUNTIF(${p}is_bounce_ua) AS bounces,
    SUM(${p}session_duration_sec) AS session_duration_sec,
    SUM(${p}page_views) AS pageviews,
    SUM(${p}unique_pages) AS unique_pageviews,
    SUM(${p}transactions) AS transactions,
    SUM(${p}revenue) AS revenue,
    SUM(${p}key_events) AS goal_completions`;
}

function uaRatios() {
  return `SAFE_DIVIDE(bounces, sessions) AS bounce_rate,
    SAFE_DIVIDE(session_duration_sec, sessions) AS avg_session_duration_sec,
    SAFE_DIVIDE(pageviews, sessions) AS pages_per_session,
    SAFE_DIVIDE(new_users, sessions) AS pct_new_sessions,
    SAFE_DIVIDE(transactions, sessions) AS ecommerce_conversion_rate,
    SAFE_DIVIDE(goal_completions, sessions) AS goal_conversion_rate`;
}

// GA4 / UA replica reports keep bots (numbers must match the UI), the rest drops them
function sessionsSource(ref, { keepBots = false } = {}) {
  const filter = !keepBots && constants.EXCLUDE_BOTS_IN_MARTS ? "WHERE NOT is_bot_suspect" : "";
  return `(SELECT * FROM ${ref} ${filter})`;
}

module.exports = { SESSION_UPSTREAM, ACTIVE_USER, activeUser, sessionMetrics, sessionRatios, uaMetrics, uaRatios, sessionsSource };
