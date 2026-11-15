// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Audiences generated from includes/cfg_audiences.js
//
//   aud_<name>                one table per audience (today's members)
//   aud_memberships_today     all audiences together, with consent and destinations
//   aud_membership_history    daily snapshots (incremental) -> who entered / left and when
//   aud_summary               size, growth, entries / exits and consent share per audience

const tz = constants.TIMEZONE;

function audienceConfig(description, extra = {}) {
  return Object.assign({
    type: "table",
    schema: constants.SCHEMAS.audiences,
    description,
    bigquery: { labels: { layer: "marts", domain: "audiences" } },
    tags: ["marts", "audiences", "daily", "activation"]
  }, extra);
}

cfg_audiences.audiences.forEach(a => {
  const name = `aud_${a.name}`;
  publish(name, audienceConfig(`Audience '${a.name}': ${a.description}. Destinations: ${(a.destinations || []).join(", ")}`))
    .query(ctx => {
      if (a.kind === "price_drop") {
        return `
WITH
recent_views AS (
  SELECT user_key, item_id, MAX(event_date) AS last_view_date, ANY_VALUE(price) AS price_when_viewed
  FROM ${ctx.ref("fct_item_interactions")}
  WHERE event_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 30 DAY)
    AND event_name = 'view_item'
    AND user_key IS NOT NULL
  GROUP BY 1, 2
),

drops AS (
  SELECT item_id, change_date, old_price, new_price, price_change_pct
  FROM ${ctx.ref("ecom_item_price_changes")}
  WHERE change_type = 'price_drop'
    AND price_change_pct <= -${a.min_drop_pct || 0.05}
    AND change_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 30 DAY)
),

bought AS (
  SELECT DISTINCT user_key, item_id FROM ${ctx.ref("fct_transaction_items")}
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 30 DAY)
)

SELECT
  CURRENT_DATE('${tz}') AS snapshot_date,
  '${a.name}' AS audience_name,
  f.user_key,
  f.user_id,
  f.user_pseudo_id,
  f.consent_ads_granted,
  ARRAY_AGG(STRUCT(v.item_id, d.old_price, d.new_price, d.price_change_pct) ORDER BY d.price_change_pct LIMIT 5) AS dropped_items,
  CURRENT_TIMESTAMP() AS loaded_at
FROM recent_views AS v
JOIN drops AS d ON d.item_id = v.item_id AND d.change_date > v.last_view_date
LEFT JOIN bought AS b ON b.user_key = v.user_key AND b.item_id = v.item_id
JOIN ${ctx.ref("aud_user_features")} AS f ON f.user_key = v.user_key
WHERE b.user_key IS NULL
GROUP BY f.user_key, f.user_id, f.user_pseudo_id, f.consent_ads_granted`;
      }
      return `
SELECT
  CURRENT_DATE('${tz}') AS snapshot_date,
  '${a.name}' AS audience_name,
  user_key,
  user_id,
  user_pseudo_id,
  consent_ads_granted,
  purchases_total,
  lifetime_revenue,
  days_since_last_purchase,
  rfm_segment,
  value_tier,
  purchase_propensity,
  churn_risk,
  CURRENT_TIMESTAMP() AS loaded_at
FROM ${ctx.ref("aud_user_features")}
WHERE ${a.condition}`;
    });
});

publish("aud_memberships_today", audienceConfig("All audience members of today in one table (audience x user), with consent and allowed destinations. Activation reads this one"))
  .query(ctx => cfg_audiences.audiences.map(a => `
SELECT
  snapshot_date,
  audience_name,
  user_key,
  user_id,
  user_pseudo_id,
  COALESCE(consent_ads_granted, FALSE) AS consent_ads_granted,
  '${a.consent || "ads"}' AS consent_required,
  [${helpers.sqlList(a.destinations || [])}] AS destinations
FROM ${ctx.ref(`aud_${a.name}`)}`).join("\nUNION ALL"));

publish("aud_membership_history", audienceConfig("Daily snapshot of the audience memberships (incremental, one partition per day). Base to know when a user entered / left an audience and to measure the audiences over time", {
  type: "incremental",
  bigquery: { partitionBy: "snapshot_date", clusterBy: ["audience_name"], labels: { layer: "marts", domain: "audiences" } }
}))
  .preOps(ctx => ctx.incremental() ? `DELETE FROM ${ctx.self()} WHERE snapshot_date = CURRENT_DATE('${tz}')` : "")
  .query(ctx => `
SELECT snapshot_date, audience_name, user_key, consent_ads_granted, CURRENT_TIMESTAMP() AS loaded_at
FROM ${ctx.ref("aud_memberships_today")}`);

publish("aud_summary", audienceConfig("Size of every audience today, 7 and 28 days ago, users that entered / left since yesterday and the share with ads consent (the part you can actually send to Google / Meta)"))
  .query(ctx => `
WITH
history AS (
  SELECT * FROM ${ctx.ref("aud_membership_history")}
  WHERE snapshot_date >= DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 28 DAY)
),

today AS (SELECT * FROM history WHERE snapshot_date = CURRENT_DATE('${tz}')),
yesterday AS (SELECT * FROM history WHERE snapshot_date = DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 1 DAY)),

sizes AS (
  SELECT
    audience_name,
    COUNTIF(snapshot_date = CURRENT_DATE('${tz}')) AS size_today,
    COUNTIF(snapshot_date = CURRENT_DATE('${tz}') AND consent_ads_granted) AS size_with_ads_consent,
    COUNTIF(snapshot_date = DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 7 DAY)) AS size_7_days_ago,
    COUNTIF(snapshot_date = DATE_SUB(CURRENT_DATE('${tz}'), INTERVAL 28 DAY)) AS size_28_days_ago
  FROM history
  GROUP BY audience_name
),

moves AS (
  SELECT
    COALESCE(t.audience_name, y.audience_name) AS audience_name,
    COUNTIF(y.user_key IS NULL) AS entered_since_yesterday,
    COUNTIF(t.user_key IS NULL) AS left_since_yesterday
  FROM today AS t
  FULL OUTER JOIN yesterday AS y ON y.audience_name = t.audience_name AND y.user_key = t.user_key
  GROUP BY 1
)

SELECT
  s.*,
  SAFE_DIVIDE(s.size_with_ads_consent, s.size_today) AS consent_share,
  COALESCE(m.entered_since_yesterday, 0) AS entered_since_yesterday,
  COALESCE(m.left_since_yesterday, 0) AS left_since_yesterday,
  CURRENT_TIMESTAMP() AS loaded_at
FROM sizes AS s
LEFT JOIN moves AS m USING (audience_name)`);
