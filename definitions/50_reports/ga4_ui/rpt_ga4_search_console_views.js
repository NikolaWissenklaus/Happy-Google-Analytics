// author: Francisco Lucas / Nikola Wissenklaus / Chico

// GA4 Reports > Search Console (the collection that appears when the property is linked to
// Search Console): Queries and Google organic search traffic. Views over the tables we already
// have, only when enable_search_console is on.

const schema = constants.SCHEMAS.reports_ga4;

publish("rpt_ga4_search_console_queries_daily", {
  type: "view",
  schema,
  disabled: !constants.ENABLE.search_console,
  description: "GA4 Reports > Search Console > Queries: organic Google search query, clicks, impressions, CTR and average position per day, country and device (web search). Brand flag from cfg_project.brand_terms. Average position of a period = SUM(position_x_impressions) / SUM(impressions)",
  tags: ["reports", "ga4_report", "daily", "seo", "search_console", "optional"]
}).query(ctx => `
SELECT
  data_date,
  COALESCE(query, '(anonymized)') AS organic_google_search_query,
  is_anonymized_query,
  is_brand_query,
  country,
  device,
  clicks AS organic_google_search_clicks,
  impressions AS organic_google_search_impressions,
  ctr AS organic_google_search_click_through_rate,
  avg_position AS organic_google_search_average_position,
  avg_position * impressions AS position_x_impressions
FROM ${ctx.ref("stg_gsc__site_impressions")}
WHERE search_type = 'WEB'`);

publish("rpt_ga4_google_organic_search_traffic", {
  type: "view",
  schema,
  disabled: !constants.ENABLE.search_console,
  description: "GA4 Reports > Search Console > Google organic search traffic: landing page with the Search Console numbers (clicks, impressions, CTR, position, last 28 days) next to the GA4 numbers of the organic sessions (sessions, engagement, purchases, revenue, revenue per click)",
  tags: ["reports", "ga4_report", "daily", "seo", "search_console", "optional"]
}).query(ctx => `
SELECT
  page_path AS landing_page,
  clicks AS organic_google_search_clicks,
  impressions AS organic_google_search_impressions,
  ctr AS organic_google_search_click_through_rate,
  avg_position AS organic_google_search_average_position,
  queries AS distinct_queries,
  sessions,
  engaged_sessions,
  engagement_rate,
  transactions AS ecommerce_purchases,
  revenue AS total_revenue,
  sessions_per_click,
  revenue_per_click
FROM ${ctx.ref("seo_landing_pages_gsc")}`);
