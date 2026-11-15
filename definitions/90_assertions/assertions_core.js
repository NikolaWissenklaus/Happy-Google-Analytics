// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Custom assertions of the core layer. An assertion returns the BAD rows: zero rows = pass.
//
// They run with the tag "assertions" (and "daily"). Dataform marks the run as failed when one
// returns rows, but it does not stop the models that do not depend on it, so the dashboards
// still update. Look at the dataset ga4_assertions to see the rows that failed.

const tz = constants.TIMEZONE;

function check(name, description, query, extraTags = []) {
  assert(name, {
    description,
    tags: ["assertions", "daily"].concat(extraTags)
  }).query(query);
}

check("assert_fct_sessions_unique_session_key",
  "fct_sessions must have one row per session_key (and no NULL key)",
  ctx => `
SELECT session_key, COUNT(*) AS rows_found
FROM ${ctx.ref("fct_sessions")}
GROUP BY session_key
HAVING COUNT(*) > 1 OR session_key IS NULL`);

check("assert_fct_transactions_unique_transaction_id",
  "fct_transactions must have one row per transaction_id. Duplicated orders = inflated revenue",
  ctx => `
SELECT transaction_id, COUNT(*) AS rows_found
FROM ${ctx.ref("fct_transactions")}
GROUP BY transaction_id
HAVING COUNT(*) > 1 OR transaction_id IS NULL`);

check("assert_user_stitching_one_row_per_device",
  "int_ga4__user_stitching must map each user_pseudo_id to exactly one user_key",
  ctx => `
SELECT user_pseudo_id, COUNT(*) AS rows_found, COUNT(DISTINCT user_key) AS user_keys
FROM ${ctx.ref("int_ga4__user_stitching")}
GROUP BY user_pseudo_id
HAVING COUNT(*) > 1`);

check("assert_no_giant_or_placeholder_users",
  "No user_key can be a placeholder ('uid:undefined', 'uid:0'...) or have more devices than cfg_identity.max_devices_per_user_id: that is a broken dataLayer or a merge gone wrong, not a person",
  ctx => `
SELECT user_key, COUNT(*) AS devices
FROM ${ctx.ref("int_ga4__user_stitching")}
GROUP BY user_key
HAVING COUNT(*) > ${cfg_identity.max_devices_per_user_id}
   OR LOWER(REGEXP_REPLACE(user_key, r'^uid:', '')) IN (${helpers.sqlList(cfg_identity.user_id_placeholders)})`);

check("assert_no_negative_revenue_in_valid_orders",
  "A valid order (is_valid_for_revenue) can not have negative revenue",
  ctx => `
SELECT transaction_id, transaction_date, revenue
FROM ${ctx.ref("fct_transactions")}
WHERE is_valid_for_revenue
  AND revenue < 0`);

check("assert_no_future_events",
  "Events dated after tomorrow (property timezone) = broken clock in the app or a bad timestamp fix",
  ctx => `
SELECT event_date, COUNT(*) AS events
FROM ${ctx.ref("stg_ga4__events")}
WHERE event_date > DATE_ADD(CURRENT_DATE('${tz}'), INTERVAL 1 DAY)
GROUP BY event_date`);

check("assert_calendar_has_no_gaps",
  "dim_calendar must be continuous, the marts join on it",
  ctx => `
SELECT date_day, previous_day
FROM (
  SELECT date_day, LAG(date_day) OVER (ORDER BY date_day) AS previous_day
  FROM ${ctx.ref("dim_calendar")}
)
WHERE previous_day IS NOT NULL
  AND DATE_DIFF(date_day, previous_day, DAY) != 1`);

check("assert_revenue_core_equals_mart",
  "Valid revenue of fct_transactions and of ecom_daily_kpis must be the same for the last 30 closed days (tolerance 0.5%). Different = a mart is filtering orders on its own",
  ctx => `
WITH
core AS (
  SELECT transaction_date AS day, SUM(IF(is_valid_for_revenue, revenue, 0)) AS revenue
  FROM ${ctx.ref("fct_transactions")}
  WHERE transaction_date BETWEEN DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 31 DAY) AND DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 2 DAY)
  GROUP BY 1
),
mart AS (
  SELECT kpi_date AS day, SUM(valid_revenue) AS revenue
  FROM ${ctx.ref("ecom_daily_kpis")}
  WHERE kpi_date BETWEEN DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 31 DAY) AND DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 2 DAY)
  GROUP BY 1
)
SELECT day, c.revenue AS core_revenue, m.revenue AS mart_revenue
FROM core AS c
FULL OUTER JOIN mart AS m USING (day)
WHERE ABS(COALESCE(c.revenue, 0) - COALESCE(m.revenue, 0)) > 0.005 * GREATEST(ABS(COALESCE(c.revenue, 0)), 1)`);

check("assert_sessions_core_equals_ga4_report",
  "Sessions of fct_sessions and of rpt_ga4_traffic_acquisition_daily must match for the last 7 closed days (tolerance 0.5%). The GA4 replica can not invent or lose sessions",
  ctx => `
WITH
core AS (
  SELECT session_date AS day, COUNT(*) AS sessions
  FROM ${ctx.ref("fct_sessions")}
  WHERE session_date BETWEEN DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 8 DAY) AND DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 2 DAY)
  GROUP BY 1
),
report AS (
  SELECT session_date AS day, SUM(sessions) AS sessions
  FROM ${ctx.ref("rpt_ga4_traffic_acquisition_daily")}
  WHERE session_date BETWEEN DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 8 DAY) AND DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 2 DAY)
  GROUP BY 1
)
SELECT day, c.sessions AS core_sessions, r.sessions AS report_sessions
FROM core AS c
FULL OUTER JOIN report AS r USING (day)
WHERE ABS(COALESCE(c.sessions, 0) - COALESCE(r.sessions, 0)) > 0.005 * GREATEST(COALESCE(c.sessions, 0), 1)`);
