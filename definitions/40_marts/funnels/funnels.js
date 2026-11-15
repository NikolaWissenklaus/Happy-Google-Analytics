// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Funnels generated from includes/cfg_funnels.js
//
// For each funnel:
//   fnl_<name>_steps         one row per session (or user) with the time of each step, open and closed
//   fnl_<name>_daily         open and closed counts per day, device, channel and new/returning
//   fnl_<name>_elapsed       time between consecutive steps (closed funnel)
//   fnl_<name>_next_actions  what people did right after the step where they gave up
// and fnl_overview with every funnel side by side (last 30 days).
//
// open funnel   = reached the step at any moment (GA4 "open funnel")
// closed funnel = reached step 1, then step 2 AFTER it, then step 3... (GA4 "closed funnel")

const tz = constants.TIMEZONE;
const windowDays = cfg_funnels.window_days;

function stepsConfig(f, description) {
  return {
    type: "table",
    schema: constants.SCHEMAS.funnels,
    description,
    bigquery: { labels: { layer: "marts", domain: "funnels", funnel: f.name } },
    tags: ["marts", "funnels", "daily"]
  };
}

cfg_funnels.funnels.forEach(f => {
  const isUser = f.scope === "user";
  const n = f.steps.length;
  const idx = [...Array(n).keys()].map(i => i + 1);
  const stepName = i => f.steps[i - 1].name;
  const limitWindow = isUser && f.window_days
    ? (prev) => `AND x.event_ts <= TIMESTAMP_ADD(${prev}, INTERVAL ${f.window_days} DAY)`
    : () => "";

  // ---------------------------------------------------------------- steps
  publish(`fnl_${f.name}_steps`, stepsConfig(f, `Funnel '${f.name}' (${f.scope} scope): ${f.description}. One row per ${isUser ? "user" : "session"} with the timestamp of each step, open and closed`))
    .query(ctx => {
      const closedCtes = idx.slice(1).map(i => `
closed_${i} AS (
  SELECT
    *,
    (SELECT MIN(x.event_ts) FROM UNNEST(evs) AS x
     WHERE x.is_step_${i} AND x.event_ts >= closed_step_${i - 1}_ts ${limitWindow(`closed_step_1_ts`)}) AS closed_step_${i}_ts
  FROM closed_${i - 1}
)`).join(",");

      return `
WITH
funnel_events AS (
  SELECT
    ${isUser ? "COALESCE(id.user_key, CONCAT('dev:', e.user_pseudo_id))" : "e.session_key"} AS entity_key,
    e.event_ts,
    ${idx.map(i => `COALESCE(${f.steps[i - 1].condition}, FALSE) AS is_step_${i}`).join(",\n    ")}
  FROM ${ctx.ref("stg_ga4__events")} AS e
  ${isUser ? `LEFT JOIN ${ctx.ref("int_ga4__user_stitching")} AS id USING (user_pseudo_id)` : ""}
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL ${windowDays} DAY)
    AND ${isUser ? "e.user_pseudo_id IS NOT NULL" : "e.session_key IS NOT NULL"}
    AND (${f.steps.map(s => `(${s.condition})`).join(" OR ")})
    ${helpers.noiseFilter("e")}
),

per_entity AS (
  SELECT
    entity_key,
    ARRAY_AGG(STRUCT(event_ts, ${idx.map(i => `is_step_${i}`).join(", ")}) ORDER BY event_ts) AS evs,
    MIN(event_ts) AS first_step_event_ts,
    ${idx.map(i => `MIN(IF(is_step_${i}, event_ts, NULL)) AS open_step_${i}_ts`).join(",\n    ")}
  FROM funnel_events
  GROUP BY entity_key
),

closed_1 AS (
  SELECT *, open_step_1_ts AS closed_step_1_ts FROM per_entity
)${closedCtes ? "," : ""}
${closedCtes}

SELECT
  c.entity_key,
  '${f.name}' AS funnel_name,
  ${isUser
    ? `DATE(c.first_step_event_ts, '${tz}') AS funnel_date,
  u.first_device_category AS device_category,
  u.first_channel AS channel,
  'new' AS user_type,`
    : `s.session_date AS funnel_date,
  s.device_category,
  s.session_default_channel_group AS channel,
  IF(s.is_new_user, 'new', 'returning') AS user_type,`}
  ${idx.map(i => `c.open_step_${i}_ts`).join(",\n  ")},
  ${idx.map(i => `c.closed_step_${i}_ts`).join(",\n  ")},
  CURRENT_TIMESTAMP() AS loaded_at
FROM closed_${n} AS c
${isUser
  ? `LEFT JOIN ${ctx.ref("dim_users")} AS u ON u.user_key = c.entity_key`
  : `JOIN ${ctx.ref("fct_sessions")} AS s ON s.session_key = c.entity_key ${helpers.martSessionFilter("s")}`}
`;
    });

  // ---------------------------------------------------------------- daily
  publish(`fnl_${f.name}_daily`, stepsConfig(f, `Funnel '${f.name}' per day, device, channel and user type: open and closed counts of each step (${f.steps.map(s => s.name).join(" > ")})`))
    .query(ctx => `
SELECT
  funnel_date,
  funnel_name,
  device_category,
  channel,
  user_type,
  COUNT(*) AS entities,
  ${idx.map(i => `COUNTIF(open_step_${i}_ts IS NOT NULL) AS open_${stepName(i)}`).join(",\n  ")},
  ${idx.map(i => `COUNTIF(closed_step_${i}_ts IS NOT NULL) AS closed_${stepName(i)}`).join(",\n  ")},
  SAFE_DIVIDE(COUNTIF(closed_step_${n}_ts IS NOT NULL), COUNTIF(closed_step_1_ts IS NOT NULL)) AS closed_conversion_rate,
  CURRENT_TIMESTAMP() AS loaded_at
FROM ${ctx.ref(`fnl_${f.name}_steps`)}
GROUP BY 1, 2, 3, 4, 5
`);

  // ---------------------------------------------------------------- elapsed time
  publish(`fnl_${f.name}_elapsed`, stepsConfig(f, `Funnel '${f.name}': time between consecutive steps of the closed funnel (median, p75, p90 in minutes) by device`))
    .query(ctx => idx.slice(0, n - 1).map(i => `
SELECT
  '${f.name}' AS funnel_name,
  ${i} AS from_step_number,
  '${stepName(i)}' AS from_step,
  '${stepName(i + 1)}' AS to_step,
  device_category,
  COUNT(*) AS entities,
  APPROX_QUANTILES(TIMESTAMP_DIFF(closed_step_${i + 1}_ts, closed_step_${i}_ts, SECOND) / 60, 100)[OFFSET(50)] AS median_minutes,
  APPROX_QUANTILES(TIMESTAMP_DIFF(closed_step_${i + 1}_ts, closed_step_${i}_ts, SECOND) / 60, 100)[OFFSET(75)] AS p75_minutes,
  APPROX_QUANTILES(TIMESTAMP_DIFF(closed_step_${i + 1}_ts, closed_step_${i}_ts, SECOND) / 60, 100)[OFFSET(90)] AS p90_minutes,
  CURRENT_TIMESTAMP() AS loaded_at
FROM ${ctx.ref(`fnl_${f.name}_steps`)}
WHERE closed_step_${i}_ts IS NOT NULL AND closed_step_${i + 1}_ts IS NOT NULL
GROUP BY device_category`).join("\nUNION ALL"));

  // ---------------------------------------------------------------- next actions after the drop
  publish(`fnl_${f.name}_next_actions`, stepsConfig(f, `Funnel '${f.name}': for people that reached a step and did NOT reach the next one, the first thing they did after (GA4 'next action' in funnel explorations, but for every step)`))
    .query(ctx => `
WITH
dropped AS (
  ${idx.slice(0, n - 1).map(i => `SELECT entity_key, ${i} AS dropped_after_step, '${stepName(i)}' AS dropped_after, closed_step_${i}_ts AS drop_ts
  FROM ${ctx.ref(`fnl_${f.name}_steps`)}
  WHERE closed_step_${i}_ts IS NOT NULL AND closed_step_${i + 1}_ts IS NULL`).join("\n  UNION ALL\n  ")}
),

following_events AS (
  SELECT
    d.dropped_after_step,
    d.dropped_after,
    d.entity_key,
    ARRAY_AGG(e.event_name ORDER BY e.event_ts LIMIT 1)[SAFE_OFFSET(0)] AS next_event
  FROM dropped AS d
  ${isUser
    ? `LEFT JOIN ${ctx.ref("int_ga4__user_stitching")} AS id ON id.user_key = d.entity_key
  LEFT JOIN ${ctx.ref("stg_ga4__events")} AS e
    ON e.user_pseudo_id = id.user_pseudo_id
    AND e.event_ts > d.drop_ts
    AND e.event_ts <= TIMESTAMP_ADD(d.drop_ts, INTERVAL 1 DAY)`
    : `LEFT JOIN ${ctx.ref("stg_ga4__events")} AS e
    ON e.session_key = d.entity_key
    AND e.event_ts > d.drop_ts`}
    AND e.event_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL ${windowDays + 1} DAY)
    AND e.event_name NOT IN ('user_engagement', 'scroll', 'session_start', 'first_visit')
  GROUP BY 1, 2, 3
)

SELECT
  '${f.name}' AS funnel_name,
  dropped_after_step,
  dropped_after,
  COALESCE(next_event, '(left / nothing else)') AS next_action,
  COUNT(*) AS entities,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY dropped_after_step)) AS share_of_drop,
  CURRENT_TIMESTAMP() AS loaded_at
FROM following_events
GROUP BY 2, 3, 4
QUALIFY ROW_NUMBER() OVER (PARTITION BY dropped_after_step ORDER BY COUNT(*) DESC) <= ${cfg_funnels.next_actions_top_n}
`);
});

// ---------------------------------------------------------------- overview of all funnels
publish("fnl_overview", {
  type: "table",
  schema: constants.SCHEMAS.funnels,
  description: "Every funnel of cfg_funnels.js side by side, last 30 days: open and closed counts per step, step conversion and conversion from the start",
  bigquery: { labels: { layer: "marts", domain: "funnels" } },
  tags: ["marts", "funnels", "daily"]
}).query(ctx => cfg_funnels.funnels.map(f => f.steps.map((s, i) => `
SELECT
  '${f.name}' AS funnel_name,
  '${f.scope}' AS scope,
  ${i + 1} AS step_number,
  '${s.name}' AS step_name,
  COUNTIF(open_step_${i + 1}_ts IS NOT NULL) AS open_count,
  COUNTIF(closed_step_${i + 1}_ts IS NOT NULL) AS closed_count,
  SAFE_DIVIDE(COUNTIF(closed_step_${i + 1}_ts IS NOT NULL), COUNTIF(closed_step_${Math.max(i, 1)}_ts IS NOT NULL)) AS closed_rate_from_previous,
  SAFE_DIVIDE(COUNTIF(closed_step_${i + 1}_ts IS NOT NULL), COUNTIF(closed_step_1_ts IS NOT NULL)) AS closed_rate_from_start
FROM ${ctx.ref(`fnl_${f.name}_steps`)}
WHERE funnel_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 30 DAY)`).join("\nUNION ALL")).join("\nUNION ALL"));
